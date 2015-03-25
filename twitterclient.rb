require 'twitter'
require 'yaml'


class TwitterClient

	attr_accessor :client

	def initialize
		#Load the configuration from file - look at the example file fo guidance
		keys = YAML.load_file('config/twitter.yaml')

		@client = Twitter::REST::Client.new do |config|
  			config.consumer_key        = keys['consumer_key']
  			config.consumer_secret     = keys['consumer_secret']
  			config.access_token        = keys['access_token']
  			config.access_token_secret = keys['access_token_secret']
  		end
	end

	def search(topic)
		@client.search(topic, result_type: "recent").take(100)
	end

	def tweet(content)
		client.update(content)
	end

	def retweet(id)
		client.retweet(id)
	end

	def user
		client.current_user
	end

	def my_retweets
		client.retweeted_by_me
	end

	def my_followers
		client.followers
	end

	def get_timeline(user_id)
		client.user_timeline(user_id, result_type: "recent")
	end

end