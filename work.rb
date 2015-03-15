require 'redis'

require './config.rb'

class Work
  def initialize
    @redis = Redis.new(url: Settings.redis["url"])
    @threshold = Settings.manager["queue_messages_threshold"].to_i
  end

  def has_more_work?
    work_items = (@redis.llen Settings.redis["queue"]).to_i
    work_items > @threshold
  end
end
