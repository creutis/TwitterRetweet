require 'sinatra'
require 'data_mapper'
require 'slim'
require_relative 'twitterclient.rb'

client = TwitterClient.new

DataMapper.setup(:default, ENV['DATABASE_URL'] || "sqlite3://#{Dir.pwd}/development.db")
DataMapper::Property::String.length(140)

class TweetsDB
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
TweetsDB.auto_upgrade!


#Looking for all my retweets and adds those to the database
retweets_by_me = client.my_retweets

retweets_by_me.each do |tweet|
	puts "Retweet [#{tweet.id}]: #{tweet.text}"
	TweetsDB.create(:tweet_id => tweet.id.to_s,
		:tweet_user_screen_name => tweet.user.screen_name,
		:tweet_text => tweet.text,
		:retweeted => true,
		:retweeted_at => Time.now)
end

#Default route
get '/' do
	slim :index
end

get '/search' do
	slim :search
end

get '/retweet' do
	slim :retweet
end

get'/db_view' do
	@tweets = TweetsDB.all(:order => [:id.desc])
	slim :db_view
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
		if TweetsDB.count(:tweet_id =>tweet.id) == 0
			#Tweet not in database - checks if the tweet should be retweeted
			retweet_this_tweet = false
			if tweet.user != client.user
				#Try and retweet - catch all errors (if error is raised the tweet will be added to the database with retweeet == false)
				begin
					client.retweet(tweet.id)
					retweet_this_tweet = true
					puts "Retweeted #{tweet.id}"
				rescue => e
					puts e.message
				end
			end

			#Creating database entry for the tweet - using the boolean if the tweet was retweeted or not
			puts "Creting database record for #{tweet.id}"
			TweetsDB.create(:tweet_id => tweet.id.to_s,
				:tweet_user_screen_name => tweet.user.screen_name,
				:tweet_text => tweet.text,
				:retweeted => retweet_this_tweet,
				:retweeted_at => Time.now)
		else
			puts "#{tweet.user.screen_name} - Twitter ID: #{tweet.id} already in database"
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