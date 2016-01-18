require File.expand_path('../lib/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Travis Reeder"]
  gem.email         = ["travis@appoxy.com"]
  gem.description   = "Tiny facebook library. By http://www.appoxy.com"
  gem.summary       = "Tiny facebook library. By http://www.appoxy.com"
  gem.homepage      = "http://github.com/appoxy/mini_fb/"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "mini_fb"
  gem.require_paths = ["lib"]
  gem.version       = MiniFB::VERSION

  gem.required_rubygems_version = ">= 1.3.6"
  gem.required_ruby_version = Gem::Requirement.new(">= 1.8")
  gem.add_runtime_dependency "httpclient", ">= 0"
  gem.add_runtime_dependency "hashie", ">= 0"
end
