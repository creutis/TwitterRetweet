require 'sinatra'
require 'data_mapper'
require 'slim'
require_relative 'twitterclient.rb'

client = TwitterClient.new

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

#Intilize the DB with all my followers

#Get all my followers
my_followers = client.my_followers
	
#Iterate over all my followers
my_followers.each do |follower|
	puts "Followers [#{follower.id}]: #{follower.screen_name} => #{follower.name} "
	FollowersDB.create(:user_name => follower.name,
		:user_screen_name => follower.screen_name,
		:user_id => follower.id,
		:latest_search => Time.now)
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

post '/retweet_from_db' do
	puts "Retweeting from DB"

	retweet_ids = []

	#Get the follower to use for retweeting - needs some testing and might need error handling if the Collection will be nil
	@retweet_follower = FollowersDB.all(:limit => 1, :order => [:latest_search.asc]).first
	puts "The follower to check is - #{@retweet_follower.user_id} - #{@retweet_follower.user_screen_name}"

	#Get all the topics to search for
	@retweet_topics = TopicsDB.all

	#Get follower timeline
	@follower_timeline = client.get_timeline(@retweet_follower.user_id)

	#Iterate over the timeline and match each tweet with the topics from the database
	@follower_timeline.each do |tweet|
		#puts "#{@retweet_follower.user_screen_name} - #{tweet.text}"
		@retweet_topics.each do |topic|
			if tweet.text.include? topic.topic
				puts "RETWEET - #{tweet.text} ==> matched topic: #{topic.topic}"
				retweet_ids.push(tweet.id)
			else
				puts "NOPE    - #{tweet.text} ==> no match to topic: #{topic.topic}"
			end
		end
	end

	puts "Will retweet the following ids - #{retweet_ids}"
	retweet_ids.each { |id|
		puts "Reetweeting #{id}"
	}

	redirect :/

end


get '/followers' do
	@followers = FollowersDB.all(:order =>[:id.desc])
	slim :followers	
end


#Route triggered by the Home button from the search results
post '/back' do
	redirect :/
end

#CRUD TOPICS

#View all topics
get '/topics' do
	@topics = TopicsDB.all(:order => [:id.desc])
	slim :topics
end

#Create new topic
post '/topics/new' do
	@topic = params[:topic]
	TopicsDB.create(:topic => @topic)
	redirect :topics
end

#Read (view) topic
get '/topics/:id' do
	@topic = TopicsDB.get(params[:id].to_s[1..-1])
	slim :edit
end

#Update topic
put '/topics/:id' do
 	t = TopicsDB.get(params[:id].to_s[1..-1])
 	t.topic = params[:topic]
 	t.save
 	redirect :topics
end

#Delete topic - confirmation
get '/topics/:id/delete' do
	@topic = TopicsDB.get(params[:id].to_s[1..-1])
	slim :delete
end

#Delete topic - delete
delete '/topics/:id/delete' do
	t = TopicsDB.get(params[:id].to_s[1..-1])
	t.destroy
	redirect :topics
end