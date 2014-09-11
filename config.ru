require 'rubygems'
require 'bundler'
require 'open-uri'
require 'uri'

Bundler.require(:default, ENV["RACK_ENV"].to_sym)

require './app'

run App
