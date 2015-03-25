require 'data_mapper'

#Database configuration
DataMapper.setup(:default, ENV['DATABASE_URL'] || "sqlite3://#{Dir.pwd}/development.db")
DataMapper::Property::String.length(140)

#Model for tweets
class TweetsDB
	include DataMapper::Resource
	property :id, Serial, :key => true
	property :tweet_id, String, :required => true
	property :tweet_user_screen_name, String
	property :tweet_text, String
	property :retweeted, Boolean
	property :retweeted_at, DateTime
end 


#Model for topics - to be used for searches
class TopicsDB
	include DataMapper::Resource
	property :id, Serial, :key => true
	property :topic, String, :required => true
end

#Model for followers - the followers of the twitter user
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