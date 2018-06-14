lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "osis2html5/version"

Gem::Specification.new do |spec|
  spec.name          = "osis2html5"
  spec.version       = Osis2Html5::VERSION
  spec.authors       = ["Tadashi Saito"]
  spec.email         = ["tad.a.digger@gmail.com"]

  spec.summary       = "OSIS to HTML5 converter"
  spec.homepage      = "https://github.com/tadd/osis2html5"

  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency 'nokogiri', '> 0'
  spec.add_runtime_dependency 'parallel', '> 0'
  spec.add_development_dependency "bundler", "~> 1.16"
  spec.add_development_dependency "rake", "> 0"
  spec.add_development_dependency "test-unit", "> 0"
end
