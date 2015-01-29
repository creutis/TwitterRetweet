require 'twitter'


class TwitterClient

	attr_accessor :client

	def initialize
		@client = Twitter::REST::Client.new do |config|
  			config.consumer_key        = "WsXwVW22PQZUg5nfeOHYwLDCj"
  			config.consumer_secret     = "hxE4wXFtlf5Vh1ZOt3zsNoF4U08saKUtBup8laOcHyUghz2Fcs"
  			config.access_token        = "2897870321-BojBADvWCAocnhshduaqS1uawv3bTjtEtdXCLK2"
  			config.access_token_secret = "uanQ9GnRj18HPBnqzaCDp0sEZy9Sy9qFolwcHpW9wavDO"
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
end

#tc = TwitterClient.new

#tc.search("#nairuby")