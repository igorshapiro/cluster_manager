require 'aws-sdk-resources'
require './config.rb'

class EC2
  # Aws.config =

  attr_accessor :client

  def initialize
    aws_cred = YAML.load_file("aws.yml")
    credentials = Aws::Credentials.new(
      aws_cred["access_key_id"],
      aws_cred["secret_access_key"]
    )
    @client = Aws::EC2::Client.new(
      region: Settings.aws["region"],
      credentials: credentials
    )
    @ec2 = Aws::EC2::Resource.new(client: @client)
  end

  def launch_instance
    puts "Launching new instance"
    response = @client.run_instances(
      image_id: Settings.aws["image_id"],
      min_count: 1,
      max_count: 1,
      instance_type: Settings.aws["instance_type"],
      key_name: Settings.aws["key_name"]
    )
    instance = response.instances.first
    instance_id = instance.instance_id
    puts "Tagging instance: #{instance_id}"
    @client.create_tags(resources: [instance_id], tags: [{
      key: Settings.aws["tag"],
      value: "true"
    }])
    puts "Waiting for instance #{instance_id}..."
    wait_for_ssh instance_id
  end

  def wait_for_ssh instance_id
    public_dns = nil
    mem_stats = nil
    puts "Waiting for instance #{instance_id} to boot"
    while mem_stats.nil?
      if public_dns.nil?
        public_dns = get_public_dns instance_id
        puts "Public DNS detected: #{public_dns}" if public_dns
      end
      if mem_stats.nil? && public_dns
        mem_stats = get_instance_resources instance_id
        puts "Resources received" if mem_stats
      end
      sleep(3)
    end
    puts "#{instance_id} is ready. #{mem_stats}"
    mem_stats
  end

  def get_public_dns instance_id
    response = @client.describe_instances(instance_ids: [instance_id])
    instance = response.reservations.first.instances.first
    return nil if instance.public_dns_name.empty?
    instance.public_dns_name
  end

  def get_resources
    get_instance_ids_for_tag(Settings.aws["tag"])
      .map{|iid| get_instance_resources(iid) }
      .select {|x| !x.nil?}
  end

  def get_instance_ids_for_tag tag
    @client.describe_tags(filters: [
      {name: 'resource-type', values: ['instance']},
      {name: 'key', values: [tag]}
    ]).tags
      .map{|x| x.resource_id}
  end

  def terminate instance_id
    puts "Terminating #{instance_id}"
    @client.terminate_instances(instance_ids: [instance_id])
  end

  def get_instance_resources instance_id
    # tasks = `ssh #{options} #{user}@#{public_dns} ps aux | grep '#{Settings.command}'`
    # mem = `ssh #{options} #{user}@#{public_dns} free -m 2> /dev/null`
    tasks = launch(instance_id, "ps aux | grep '#{Settings.command}'").split("\n") rescue []
    mem = launch instance_id, "free -m" rescue ""
    return nil unless mem.match(/(\d+)\s+(\d+)\s+(\d+)/)
    {
      instance_id: instance_id,
      total: $1.to_i,
      used: $2.to_i,
      free: $3.to_i,
      max_tasks: Settings.manager["tasks_per_machine"],
      running_tasks: tasks.length
    }
  end

  def launch instance_id, cmd
    public_dns = get_public_dns instance_id
    return "" if public_dns.nil? || public_dns.empty?
    user = "ec2-user"
    options = '-o "StrictHostKeyChecking no"'
    cmd = "ssh #{options} #{user}@#{public_dns} #{cmd} 2> /dev/null"
    # puts "Running: #{cmd}"
    `#{cmd}`
  end
end
