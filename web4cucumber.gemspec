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
  s.add_dependency = "watir-webdriver"
  s.add_dependency = "headless"
  s.add_dependency = "byebug"
  s.add_development_dependency "bundler", "~> 1.6"
  s.add_development_dependency "rake"
end
