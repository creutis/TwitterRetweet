require 'sinatra'
require 'data_mapper'
require 'slim'
require 'logger'
require_relative 'twitterclient.rb'

$LOG = Logger.new('./logs/application.log', 10, 1024000)
$LOG.datetime_format = '%Y-%m-%d %H:%M:%S'

$LOG.info("Starting the application")

client = TwitterClient.new

puts "---- GETTING RETWEETS ----"
$LOG.info("Initializing database with retweets from Twitter API")
#Looking for all my retweets and adds those to the database
begin
	retweets_by_me = client.my_retweets
rescue => e
	puts e.message
	retweets_by_me = []
end

retweets_by_me.each do |tweet|
	puts "[#{tweet.id}] ADDED TO DB: #{tweet.text}"
	$LOG.info("#{tweet.id} - #{tweet.text} added to the database")
	TweetsDB.create(:tweet_id => tweet.id.to_s,
		:tweet_user_screen_name => tweet.user.screen_name,
		:tweet_text => tweet.text,
		:retweeted => true,
		:retweeted_at => Time.now)
end

puts "----- GETTING FOLLOWERS -----"
$LOG.info("Initializing database with followers from Twitter API")
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
	puts "[#{follower.id}] ADDED TO DB: #{follower.screen_name} => #{follower.name}"
	$LOG.info("[#{follower.id}] - #{follower.screen_name} => #{follower.name} added to the database")
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
	$LOG.info("ROUTING get /")
	slim :index
end

get '/search' do
	$LOG.info("ROUTING get /search")
	slim :search
end

get '/retweet' do
	$LOG.info("ROUTING get /retweet")
	slim :retweet
end

get '/db_view' do
	$LOG.info("ROUTING get /db_view")
	@tweets = TweetsDB.all(:order => [:id.desc])
	slim :db_view
end

#Route triggered by the search button
post '/results' do
	$LOG.info("ROUTING post /results")
	@topic = params[:topic]
	#Search for a specific topic
	@results = client.search(@topic)
	slim :results
end

#Route triggered by the Home button from the search results
post '/back' do
	$LOG.info("ROUTING post /back")
	redirect :/
end

post '/retweet' do
	$LOG.info("ROUTING post /retweet")
	puts "----- RETWEET -----"
	
	@twitter_search = client.search("#nairuby")

	@twitter_search.each do |tweet|
		puts "... checking if retweetable - #{tweet.id} - #{tweet.text}"
		if TweetsDB.count(:tweet_id =>tweet.id) == 0
			#Tweet not in database - checks if the tweet should be retweeted
			retweet_this_tweet = false
			if tweet.user != client.user
				#Try and retweet - catch all errors (if error is raised the tweet will be added to the database with retweeet == false)
				begin
					client.retweet(tweet.id)
					retweet_this_tweet = true
					puts "... retweeted #{tweet.id}"
				rescue => e
					puts e.message
				end
			end

			#Creating database entry for the tweet - using the boolean if the tweet was retweeted or not
			puts "... adding the tweet to the database - #{tweet.id}"
			TweetsDB.create(:tweet_id => tweet.id.to_s,
				:tweet_user_screen_name => tweet.user.screen_name,
				:tweet_text => tweet.text,
				:retweeted => retweet_this_tweet,
				:retweeted_at => Time.now)
		else
			puts "... tweet already in the database or error from twitter -  [#{tweet.id}]"
		end
	end

	redirect :/
end

post '/retweet_from_db' do
	puts "------ RETWEETING USING THE DB ------"

	to_be_retweeted = []
	not_to_be_retweeted = []

	this_user = client.user

	#Get the follower to use for retweeting - needs some testing and might need error handling if the Collection will be nil
	@retweet_follower = FollowersDB.all(:limit => 1, :order => [:latest_search.asc]).first
	puts "... checking follower: #{@retweet_follower.user_id} - #{@retweet_follower.user_screen_name}"

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
					puts "[#{tweet.id}] MATCH: #{tweet.text} ==> matching #{topic.topic}"
				end
			end
		end

		if retweet
			#puts "RETWEET - #{tweet.text}"
			to_be_retweeted.push(tweet)
		else
			puts "[#{tweet.id}] NO MATCH: #{tweet.text}"
			not_to_be_retweeted.push(tweet)
		end
	end

	#First I will need to scrub each retweets that should not be retweeted
	# => 1. Check user_id of the tweet with client.user - I can't retweet my own tweets
	# => 2. Check if twitter id is already in the database
	# => 3. Try and retweet - catch all errors...

	#Retweet all tweets that matched the topics in the database
	puts "----- RETWEETING MATCHING TWEETS -----"
	to_be_retweeted.each do |tweet|
		# Flag used in the database if the tweet was retweeted or not
		retweet = false
		# Check if tweet is in the databse
		if TweetsDB.count(:tweet_id =>tweet.id) == 0
			#Tweet not in database - checks if the tweet should be retweeted
			if tweet.user != this_user
				#Try and retweet - catch all errors (if error is raised the tweet will be added to the database with retweeet == false)
				begin
					client.retweet(tweet.id)
					puts "... retweeting ==> #{tweet.id}"
					retweet = true
				rescue => e
					puts "ERROR ==> #{e.message} [#{tweet.id}]"
				end
			else
				puts "... can't retweet your own tweets"
			end

			#Creating database entry for the tweet - using the boolean if the tweet was retweeted or not
			puts "... creating database record for #{tweet.id}"
			TweetsDB.create(:tweet_id => tweet.id.to_s,
				:tweet_user_screen_name => tweet.user.screen_name,
				:tweet_text => tweet.text,
				:retweeted => retweet,
				:retweeted_at => Time.now)
		else
			puts "... already in the database - #{tweet.id}"
		end
	end

	#Iterate over all tweet not to be retweeeted
	not_to_be_retweeted.each { |tweet|
		puts "... will not be retweeted - #{tweet.id}"
	}

	#Update the followers database entry for the follower used
	puts "... updating the follower in the db with new :latest_search"
	FollowersDB.get(@retweet_follower.id).update(:latest_search => Time.now)

	redirect :/

end


get '/followers' do
	@followers = FollowersDB.all(:order =>[:id.desc])
	slim :followers	
end

# Update followers in the DB - add new followers and destroy db entries for followers not following anymore
post '/update_followers' do
	

	puts "----- GETIING ALL FOLLOWERS FROM TWITTER -----"
	begin
		# Get all followers from twitter
		@followers_from_twitter = client.my_followers
	rescue => e
		puts e.message
	end
	puts "... found #{@followers_from_twitter.count}"

	puts "----- GETIING ALL FOLLOWERS FROM DB -----"
	# Get all followers from DB
	@followers_from_db = FollowersDB.all(:order =>[:id.desc])
	puts "... found #{@followers_from_db.count}"

	puts "----- ADDING FOLLOWERS TO DB -----"
	# Iterate over all followers from twitter
	@followers_from_twitter.each do |follower|
		puts "Matching follower from twitter: #{follower.id} - #{follower.screen_name}"
		follower_id_from_twitter = follower.id
		follower_in_db =false
		# For each follower from twitter check if that follower is in the DB
		@followers_from_db.each do |follower_from_db|
			puts "... with #{follower_from_db.user_id} from db"
			if follower_id_from_twitter == follower_from_db.user_id
				puts "... follower already in db"
				# Only change the flag when the follower form twitter is found in the db
				follower_in_db = true
			end
		end
		# If the follower was not found in the DB - add it!
		if !follower_in_db
			puts "----- ADDING FOLLOWER [#{follower.id} - #{follower.screen_name}] TO DB -----"
			FollowersDB.create(:user_name => follower.name,
				:user_screen_name => follower.screen_name,
				:user_id => follower.id,
				:latest_search => Time.now)
		end
	end

	puts "----- SCRUBBING FOLLOWERS IN DB -----"
	# Check all followers in the DB and remove those not following anymore
	@followers_from_db.each do |follower_db|
		puts "Matching follower from DB: #{follower_db.user_id} - #{follower_db.user_screen_name}"
		follower_id_from_db = follower_db.user_id
		follower_on_twitter = false
		# For each follower in the DB check if that follower is also actually following still
		@followers_from_twitter.each do |follower_twitter|
			puts "... with #{follower_twitter.id} from twitter"
			if follower_id_from_db == follower_twitter.id
				puts "... follower also follower on twitter"
				# Update only when finding a match
				follower_on_twitter = true
			end
		end
		# If the follower in the db was not found from the follower on twitter - remove it from the db
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