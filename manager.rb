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

  def busiest_instance machines
    machines
      .select{|r| r[:max_tasks] > r[:running_tasks]}
      .sort_by{|r| r[:running_tasks]}
      .reverse          # We'll run the process on the machine with most tasks
      .first
  end

  def run_on_busiest_instance existing_instances
    instance = busiest_instance(existing_instances) || @ec2.launch_instance
    @ec2.launch instance[:instance_id],
      "'nohup #{Settings.command} `</dev/null` > #{SecureRandom.hex(5)}.out 2>&1 &'"
    puts "Process launched"
  end

  def terminate_redundant! instances
    available_slots = instances
      .map{|inst| inst[:max_tasks] - inst[:running_tasks]}
      .inject(0){|acc, n| acc + n}

    # If we have (tasks_per_machine + 2) available slots - we'll shutdown an empty instance
    if available_slots > Settings.manager["tasks_per_machine"].to_i + 2
      puts "Shitting down empty instances. Available capacity = #{available_slots}"
      instances
        .select{|inst| inst[:running_tasks] == 0}
        .each{|inst| @ec2.terminate inst[:instance_id]}
    end
  end

  def run
    system "clear"
    while true
      instances = @ec2.get_resources
      puts instances

      terminate_redundant! instances

      if @work.has_more_work?
        puts "Found more work. Launching process"
        available_resources = run_on_busiest_instance instances
      end

      sleep @poll_interval_sec
    end
  end
end
