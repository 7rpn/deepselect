
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "deepselect/version"

Gem::Specification.new do |spec|
  spec.name          = "deepselect"
  spec.version       = Deepselect::VERSION
  spec.authors       = ["7rpn"]
  spec.email         = ["7rpn.deadlock@gmail.com"]

  spec.summary       = %q{Image recognition library for Ruby}
  spec.description   = %q{Provides a method to retrieve the image most similar to the specified image from the array.}
  spec.homepage      = "https://github.com/7rpn/deepselect"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "menoh"
  spec.add_runtime_dependency "rmagick"

  spec.add_development_dependency "bundler", "~> 1.16"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end
