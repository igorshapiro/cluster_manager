require './ec2'
require './config.rb'
require './work.rb'

class Manager
  def initialize
    @ec2 = EC2.new
    @poll_interval_sec = Settings.manager["queue_poll_interval_sec"]
    @work = Work.new
    @task_memory = Settings.manager["task_memory_mb"].to_i
  end

  def get_available_resource existing_resources
    available_resources = existing_resources.select{|r| r[:free] > @task_memory}
    if available_resources.empty?
      puts "No available machines. Creating one..."
      @ec2.launch_instance
    end
  end

  def run
    system "clear"
    while true
      resources = @ec2.get_resources
      puts resources

      if @work.has_more_work?
        puts "Found more work. Launching process"
        available_resources = get_available_resource resources
      end

      sleep @poll_interval_sec
    end
  end
end
