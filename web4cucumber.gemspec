lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'web4cucumber/version'

Gem::Specification.new do |s|
  s.name        = "web4cucumber"
  s.version     = Web4Cucumber::VERSION
  s.date        = "2015-02-28"
  s.summary     = "Web testing module for cucumber"
  s.description = "Store page and action descriptions in yaml files, 
  use this library to perform all low-level Watir-webdriver calls"
  s.authors     = ["Oleg Fayans"]
  s.email       = ["ofajans@gmail.com"]
  s.homepage    = "https://github.com/ofayans/web4cucumber"
  s.license       = "GPLv3"
  s.files         = `git ls-files`.split("\n")
  s.require_paths = ["lib"]
  s.add_runtime_dependency "watir-webdriver", "~> 0.6"
  s.add_runtime_dependency "headless", "~> 1.0"
  s.add_runtime_dependency "byebug", "~> 2.7"
  s.add_development_dependency "bundler", "~> 1.6"
  s.add_development_dependency "rake", "~> 10.0"
end
