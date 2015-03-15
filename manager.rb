require './ec2'
require './config.rb'
require './work.rb'

class Manager
  def initialize
    @ec2 = EC2.new
    @poll_interval_sec = Settings.manager["queue_poll_interval_sec"]
    @work = Work.new
    @max_tasks = Settings.manager["tasks_per_machine"]
  end

  def get_available_resource existing_resources
    available_resource = existing_resources
      .select{|r| r[:max_tasks] > r[:running_tasks]}
      .sort_by{|r| r[:running_tasks]}
      .reverse
      .first
    if available_resource.nil?
      puts "No available machines. Creating one..."
      available_resource = @ec2.launch_instance
    end
    @ec2.launch available_resource[:instance_id],
      "'nohup #{Settings.command} `</dev/null` > #{SecureRandom.hex(5)}.out 2>&1 &'"
    puts "Process launched"
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
