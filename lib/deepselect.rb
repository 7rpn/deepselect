require_relative "deepselect/version"
require 'rmagick'
require 'menoh'

require 'matrix'
require 'open-uri'
require 'fileutils'

class DSelect
	@@vgg16_obj = nil
	# self使いすぎではないでしょうか...？ pythonかな？
	# いずれselfを使わない形で書き直すか諦めてclass << selfする

	# image同士を比較して特徴量出す
	def self.compare(f1, f2)
		# 引数がRmagick imageならfeature vectorへ変換
		if f1.class == Magick::Image and f2.class == Magick::Image
			f1,f2 = f1.to_vector, f2.to_vector # さすがに他のライブラリと被りそうな気が
		end

		# cos similarity
		v1 = Vector.elements(f1)
		v2 = Vector.elements(f2)
		return v2.inner_product(v1)/(v1.norm() * v2.norm())
	end

	# vgg16返す
	def self.vgg16
		# 読み込み済みなら読み込んであるモデルを返す
		return @@vgg16_obj if @@vgg16_obj

		vgg16_dir = File.expand_path('./deepselect/data/VGG16.onnx', __dir__)
		if File.exist?(vgg16_dir)
			@@vgg16_obj = Menoh::Menoh.new(vgg16_dir)
		else
			# menohと同じようにモデルをダウンロードする
			# url勝手に使うのダメだったら教えてください...！
			model_parent_dir = File.expand_path('./deepselect/data', __dir__)
			FileUtils.mkdir(model_parent_dir) unless File.exist?(model_parent_dir)
			puts "model data downloading... (first time only)"
			url = 'https://www.dropbox.com/s/bjfn9kehukpbmcm/VGG16.onnx?dl=1'
			open(url) do |file|
				File.open(vgg16_dir, "wb") do |out|
					out.write(file.read)
				end
			end
			@@vgg16_obj = Menoh::Menoh.new(vgg16_dir)
		end
		return  @@vgg16_obj
	end

	# ...？ modelの各layerのid
	def self.id
		conv1_id = '140326425860192'.freeze
		fc6_id = '140326200777584'.freeze
		softmax_id = '140326200803680'.freeze
		{conv1_id: conv1_id, fc6_id: fc6_id, softmax_id:softmax_id}
	end

	# モデルの詳細
	def self.model_opt
		conv1_id, fc6_id, softmax_id = self.id.values

		input_shape = {
			channel_num: 3,
  			width: 224,
  			height: 224
		}
		model_opt = {
			backend: 'mkldnn',
			input_layers: [
				{
					name: conv1_id,
					dims: [
						1, #image_list.size, # batch size
						input_shape[:channel_num],
						input_shape[:height],
						input_shape[:width],
					]
				}
			],
			output_layers: [fc6_id, softmax_id]
		}
	end
end

class Magick::Image
	# dselect内かどうかのフラグ もう少しいい書き方ないのか
	attr_accessor :in_dselect

	# calcurated feature vector
	# モデルの情報とかもclassに保持するとよいかも
	@vector = nil

	# batch処理したほうが速いだろうけど
	# とりあえず逐次処理
	def to_vector
		return @vector if @vector

		vgg16 = DSelect.vgg16
		opt = DSelect.model_opt
		model = vgg16.make_model(opt)

		# onnx variable name
		conv1_id, fc6_id, softmax_id = DSelect.id.values
		
		image = self.to_menoh_image
		image_set = [{ name: conv1_id, data: image}]
		result = model.run(image_set)

		network_output = result.find { |x| x[:name] == fc6_id }
		@vector = network_output[:data].first

		return @vector
	end
	# alias :to_v :to_vector さすがに他のライブラリと被りそうな気が

	alias :default_equal :==
	def ==(image)
		if self.in_dselect or image.in_dselect
			# guard
			unless image.class == Magick::Image
				raise "現状dselectの比較相手はMagick::Imageのみ対応です" +
				"images.dselect{|dselect_image| dselect_image == image} のノリで"
			end
			DSelect.compare(self, image)
		else
			return self.default_equal(image)
		end
	end

	def to_menoh_image
		# TODO: DRYできていない場所が多すぎるので直す
		# model_optから引っ張ってくるのありだろうけどめんどいな
		input_shape = {
			channel_num: 3,
  			width: 224,
  			height: 224
		}
		image = self.resize_to_fill(input_shape[:width], input_shape[:height])
		'BGR'.split('').map do |color|
			image.export_pixels(0, 0, image.columns, image.rows, color).map { |pix| pix / 256 }
		end.flatten
	end

	def comapre_vector(image)
		if image.class != Magick::Image # or image.class != Array
			# 文章長すぎ
			err_stdout = "Error: あとでErrorClass名追加します
			 compare対象はMagick::Imageでないと駄目です
			 compare arg must be Magick::Image"
			raise err_stdout
		end
		return DSelect.compare(self, image)
	end
end 

class Array
	# block内で比較された対象の画像に，いちばん似てる画像を取り出すメソッド
	def deepselect(take: "default", with: "")
		return enum_for(__method__) unless block_given?
		
		# dselect内かどうかのフラグ
		# このフラグががtrueだと == をした時に特徴量を返す
		self.each do |image|
			image.in_dselect = true
		end

		# 特徴量計算
		feature_vectors = self.map do |image|
			result = yield image
			unless result.class == Float
				raise "Not a proper value is returned in dselect block" 
			end
			result 
		end

		self.each do |image| # 元に戻す
			image.in_dselect = nil
		end

		# 特徴量が大きい順に並べる
		zipped_image = [self, feature_vectors].transpose.map.with_index{|(image, num),i| [image, num, i]}
		result = zipped_image.sort_by{|image, num,i| num}.reverse

		# 指定された引数によって出力を変える
		if with =~ /sim/ and with =~ /ind/ # 類似度とindex両方出力
			#  pass
		elsif with =~ /sim/ # 類似度のみ
			result = result.map{|image, num,i| [image,num] }
		elsif with =~ /ind/ # indexのみ
			result = result.map{|image, num,i| [image,i] }
		else # どちらも出力しない，imageのみ返す
			result = result.map{|image, num,i| image }
		end

		# 上位いくつ取得する？
		if take == "default"
			return result.first
		end
		if take == "all"
			return result
		end
		if take.to_i > 0
			return result.take(take.to_i)
		end
		raise "what is this arg error\ntake: #{take}" #このエラーはどうなのよ
	end
	alias :dselect :deepselect

	# 初回の特徴量計算に時間がかかるため，事前にキャッシュしておきたい場合に叩くメソッド
	# batch処理する仕様にすればもっと速いけど作りがめんどくなりそう
	def deepinit
		self.each do |image|
			image.to_vector
		end
	end
	alias :dinit :deepinit
end	