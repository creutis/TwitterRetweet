require 'sinatra'
require 'data_mapper'
require 'slim'
require_relative 'twitterclient.rb'

client = TwitterClient.new

puts "---- GETTING RETWEETS ----"
#Looking for all my retweets and adds those to the database
begin
	retweets_by_me = client.my_retweets
rescue => e
	puts e.message
	retweets_by_me = []
end

retweets_by_me.each do |tweet|
	puts "Retweet [#{tweet.id}]: #{tweet.text}"
	TweetsDB.create(:tweet_id => tweet.id.to_s,
		:tweet_user_screen_name => tweet.user.screen_name,
		:tweet_text => tweet.text,
		:retweeted => true,
		:retweeted_at => Time.now)
end
puts "----- FINISHED GETTING RETWEETS -----"

puts "----- GETTING FOLLOWERS -----"
#Intilize the DB with all my followers

#Get all my followers
begin
	my_followers = client.my_followers
rescue
	puts e.message
	my_followers = []
end
	
#Iterate over all my followers and add them to the database
my_followers.each do |follower|
	puts "Followers [#{follower.id}]: #{follower.screen_name} => #{follower.name} "
	FollowersDB.create(:user_name => follower.name,
		:user_screen_name => follower.screen_name,
		:user_id => follower.id,
		:latest_search => Time.now)
end


#Only for testing - should be removed
TopicsDB.create(:topic => "@NairubyKE")
TopicsDB.create(:topic => "#mtg")

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

#Route triggered by the Home button from the search results
post '/back' do
	redirect :/
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

	to_be_retweeted = []
	not_to_be_retweeted = []

	this_user = client.user

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
		retweet = false
		@retweet_topics.each do |topic|
			if !retweet
				if tweet.text.include? topic.topic
					retweet = true
					puts "RETWEET - #{tweet.text} ==> matching #{topic.topic}"
				end
			end
		end

		if retweet
			puts "RETWEET - #{tweet.text}"
			to_be_retweeted.push(tweet)
		else
			puts "NOPE    - #{tweet.text}"
			not_to_be_retweeted.push(tweet)
		end
	end

	#First I will need to scrub each retweets that should not be retweeted
	# => 1. Check user_id of the tweet with client.user - I can't retweet my own tweets
	# => 2. Check if twitter id is already in the database
	# => 3. Try and retweet - catch all errors...

	#Iterate over all tweets to be retweeted
	puts "These will be retweeted - #{to_be_retweeted}"
	to_be_retweeted.each { |tweet|
		puts "Reetweeting #{tweet.id}"
	}

	#Retweet all tweets that matched the topics in the database
	to_be_retweeted.each do |tweet|
		retweet = false
		if TweetsDB.count(:tweet_id =>tweet.id) == 0
			#Tweet not in database - checks if the tweet should be retweeted
			if tweet.user != this_user
				#Try and retweet - catch all errors (if error is raised the tweet will be added to the database with retweeet == false)
				begin
					client.retweet(tweet.id)
					puts "RETWEET ==> #{tweet.id}"
					retweet = true
				rescue => e
					puts "ERROR ==> #{e.message} [#{tweet.id}]"
				end
			end

			#Creating database entry for the tweet - using the boolean if the tweet was retweeted or not
			puts "Creting database record for #{tweet.id}"
			TweetsDB.create(:tweet_id => tweet.id.to_s,
				:tweet_user_screen_name => tweet.user.screen_name,
				:tweet_text => tweet.text,
				:retweeted => retweet,
				:retweeted_at => Time.now)
		else
			puts "#{tweet.user.screen_name} - Twitter ID: #{tweet.id} already in database"
		end
	end

	#Iterate over all tweet not to be retweeeted
	puts "These will not be retweeted - #{not_to_be_retweeted}"
	not_to_be_retweeted.each { |tweet|
		puts "Not Retweeting #{tweet.id}"
	}

	redirect :/

end


get '/followers' do
	@followers = FollowersDB.all(:order =>[:id.desc])
	slim :followers	
end

post '/update_followers' do
	
	puts "----- GETIING ALL FOLLOWERS FROM TWITTER -----"
	begin
		@followers_from_twitter = client.my_followers
	rescue => e
		puts e.message
	end
	puts "... found #{@followers_from_twitter.count}"

	puts "----- GETIING ALL FOLLOWERS FROM DB -----"
	@followers_from_db = FollowersDB.all(:order =>[:id.desc])
	puts "... found #{@followers_from_db.count}"

	puts "----- ADDING FOLLOWERS TO DB -----"
	@followers_from_twitter.each do |follower|
		puts "Matching follower from twitter: #{follower.id} - #{follower.screen_name}"
		follower_id_from_twitter = follower.id
		follower_in_db =false
		@followers_from_db.each do |follower_from_db|
			puts "... with #{follower_from_db.user_id} from db"
			if follower_id_from_twitter == follower_from_db.user_id
				puts "... follower already in db"
				follower_in_db = true
			end
		end
		if !follower_in_db
			puts "----- ADDING FOLLOWER [#{follower.id} - #{follower.screen_name}] TO DB -----"
			FollowersDB.create(:user_name => follower.name,
				:user_screen_name => follower.screen_name,
				:user_id => follower.id,
				:latest_search => Time.now)
		end
	end

	puts "----- SCRUBBING FOLLOWERS IN DB -----"
	@followers_from_db.each do |follower_db|
		puts "Matching follower from DB: #{follower_db.user_id} - #{follower_db.user_screen_name}"
		follower_id_from_db = follower_db.user_id
		follower_on_twitter = false
		@followers_from_twitter.each do |follower_twitter|
			puts "... with #{follower_twitter.id} from twitter"
			if follower_id_from_db == follower_twitter.id
				puts "... follower also follower on twitter"
				follower_on_twitter = true
			end
		end
		if !follower_on_twitter
			puts "----- REMOWING FOLLOWER [#{follower_db.user_id} - #{follower_db.user_screen_name}] FROM DB -----"
			FollowersDB.destroy(follower_db.id)
		end
	end

	redirect :followers
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