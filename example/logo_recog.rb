require 'open-uri'
require 'rmagick'
require 'menoh'

require "deepselect"

# ありがちな喫茶店ロゴ画像５つ
name_list = [
	"logo_doutor.jpg", "logo_stmarc.png",
	"logo_komeda.jpeg", "logo_starbucks.png",
	"logo_tully's.jpg"
]

# 全部Magick::Imageとして読み込んでimages配列にぶちこむ
images = name_list.map do |name|
	image_dir = "./images/"+name
	image = Magick::Image.read(image_dir).first
end

# スターバックスの画像を読み込む
starbucks_image = Magick::Image.read("./images/image_starbucks.png").first
puts "input: #{"./images/image_starbucks.png"} "

# 配列の中から一番近い画像を取り出す
selected_image = images.dselect{|dimage| dimage == starbucks_image}
puts "output: #{selected_image.filename}"  # => ./images/logo_starbucks.png


# スターバックスの画像もうひとつ
starbucks_image = Magick::Image.read("./images/image_starbucks2.jpg").first
selected_image = images.dselect{|dimage| dimage == starbucks_image}
puts "一番似ている画像は'#{selected_image.filename}'です" 

# コメダもやってみる
komeda_image = Magick::Image.read("./images/image_komeda.jpg").first
selected_image = images.dselect{|dimage| dimage == komeda_image}
puts "一番似ている画像は'#{selected_image.filename}'です" 

# タリーズも
tullys_image = Magick::Image.read("./images/image_tully's.png").first
selected_image = images.dselect{|dimage| dimage == tullys_image}
puts "一番似ている画像は'#{selected_image.filename}'です" 


# コメダの写真だったら...？
komeda_photo_image = Magick::Image.read("./images/photo_komeda.jpg").first
selected_image = images.dselect{|dimage| dimage == komeda_photo_image}
puts "一番似ている画像は'#{selected_image.filename}'です" 

# スタバの写真，失敗する
starbucks_photo_image = Magick::Image.read("./images/photo_starbucks.jpg").first
selected_image = images.dselect{|dimage| dimage == starbucks_photo_image}
puts "一番似ている画像は'#{selected_image.filename}'です" 

# スタバの写真，ここまで寄せれば成功
starbucks_photo_image2 = Magick::Image.read("./images/photo_starbucks2.png").first
selected_image = images.dselect{|dimage| dimage == starbucks_photo_image2}
puts "一番似ている画像は'#{selected_image.filename}'です" 

# サンマルクの写真
stmark_photo_image = Magick::Image.read("./images/photo_stmarc.jpg").first
selected_image = images.dselect(take: 2, with: "similarity, index"){|dimage| dimage == stmark_photo_image}
p selected_image