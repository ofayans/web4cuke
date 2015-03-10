#!/usr/bin/env ruby
require 'rspec/expectations'
LIB_PATH = File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'lib'))
$LOAD_PATH.unshift(LIB_PATH)
require "web"
require "log"

Before do |scenario|
  options = {
    :base_url => "https://openshift.com",
    :browser => :firefox,
    :rules_path => File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'lib', 'web')),
    :logger => Log.new
  }
  @web = Web.new(options)
end

After do |scenario|
  @web.finalize
end
