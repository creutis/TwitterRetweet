require 'data_mapper'

#Database configuration
DataMapper.setup(:default, ENV['DATABASE_URL'] || "sqlite3://#{Dir.pwd}/development.db")

DataMapper::Property::String.length(140)

# Data model for tweets
#
# Properties
# :id						Id created for each entry in the db
# :tweet_id 				Id of the tweet - from Twitter API
# :tweet_user_screen_name 	Screen name of the user of the tweet - from Twitter API
# :tweet_text 				The actual text of the tweet - from Twitter API
# :retweeted 				Boolean holding if the tweet was retweeted or not, used for 
# 							keeping unwanted tweets to be matched and retweeted again
# : retweeted_at 			Date for when the tweet was retweeted
class TweetsDB
	include DataMapper::Resource
	property :id, Serial, :key => true 
	property :tweet_id, String, :required => true 
	property :tweet_user_screen_name, String 
	property :tweet_text, String 
	property :retweeted, Boolean 
	property :retweeted_at, DateTime 
end 


# Model for topics - to be used for searches
#
# Properties
# :id 						Id created for each entry in the db
# :topic 					Topic in plain text - when adding new topic please add @ or # as well 
class TopicsDB
	include DataMapper::Resource
	property :id, Serial, :key => true #Id created for 
	property :topic, String, :required => true
end

# Model for followers - the followers of the twitter user
#
# :id
# :user_id
# :user_screen_name
# :user_name
# :latest_search
class FollowersDB
	include DataMapper::Resource
	property :id, Serial, :key => true
	property :user_id, Integer
	property :user_screen_name, String
	property :user_name, String
	property :latest_search, DateTime
end


#Perform sanity checks and initialize all relationships, call after all models are defined
DataMapper.finalize
DataMapper.auto_migrate!

#Automatically create the tables
TweetsDB.auto_upgrade!
TopicsDB.auto_upgrade!
FollowersDB.auto_upgrade!