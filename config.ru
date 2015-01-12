require 'bundler'
Bundler.require
require './app.rb'
require './twitterclient.rb'
 
DataMapper.setup(:default, ENV['DATABASE_URL'] || "sqlite3://#{Dir.pwd}/development.db")
 
run Sinatra::Application