require 'sinatra'
require 'data_mapper'
require 'slim'
require_relative 'twitterclient.rb'

client = TwitterClient.new

DataMapper.setup(:default, ENV['DATABASE_URL'] || "sqlite3://#{Dir.pwd}/development.db")

class Tweets
	include DataMapper::Resource
	property :id, Serial
	property :tweet_id, String, :required => true
	property :tweet_user_screen_name, String
	property :tweet_text, String
	property :retweeted, Boolean
	property :retweeted_at, DateTime
end 

#Perform sanity checks and initialize all relationships, call after all models are defined
DataMapper.finalize
DataMapper.auto_migrate!

#Automatically create the Tweets table
Tweets.auto_upgrade!

#Create one default post in the database
@intial_datapost = Tweets.create(:tweet_id => "1111111111",
	:tweet_user_screen_name => "INITIAL POST",
	:tweet_text => "THIS SHOULD BE REMOVED",
	:retweeted => false,
	:retweeted_at => Time.now)

#Default route
get '/' do
	@tweets = Tweets.all(:order => [ :id.desc])
	slim :index
end

get '/search' do
	slim :search
end

get '/retweet' do
	slim :retweet
end


#Route triggered by the search button
post '/results' do
	@topic = params[:topic]
	#Search for a specific topic
	@results = client.search(@topic)
	slim :results
end

post '/retweet' do
	puts "Time to retweet"
	
	@twitter_search = client.search("#nairuby")

	@twitter_search.each do |tweet|
		puts "Twitter id: #{tweet.id} - #{tweet.text}"
		if Tweets.count(:tweet_id =>tweet.id) == 0
			puts "Creting database record for #{tweet.id}"
			Tweets.create(:tweet_id => tweet.id.to_s,
				:tweet_user_screen_name => tweet.user.screen_name,
				:tweet_text => tweet.text,
				:retweeted => true,
				:retweeted_at => Time.now)
			puts "Retweeting #{tweet.id}"
			client.retweet(tweet.id)
		else
			puts "Twitter ID: #{tweet.id} already in database"
		end
	end

	redirect :/
end

#Route triggered by the Home button from the search results
post '/back' do
	redirect :/
end

#Direct route for testing the search function
#get '/search' do
#	@results = client.search("#nairuby")
#	slim :results
#end