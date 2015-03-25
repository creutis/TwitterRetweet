require 'bundler'
Bundler.require
require './db/models.rb'
require './app.rb'
require './twitterclient.rb'

DataMapper.setup(:default, ENV['DATABASE_URL'] || "sqlite3://#{Dir.pwd}/development.db")
 
run Sinatra::Application