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
    # puts "Created instance: #{instance.inspect}"
    #
    # @client.wait_until(:instance_running, instance_ids: [instance_id])
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
        mem_stats = free_mem instance_id
        puts "Memory stats received" if mem_stats
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
      .map{|iid| free_mem(iid) }
      .select {|x| !x.nil?}
  end

  def get_instance_ids_for_tag tag
    @client.describe_tags(filters: [
      {name: 'resource-type', values: ['instance']},
      {name: 'key', values: [tag]}
    ]).tags
      .map{|x| x.resource_id}
  end

  def free_mem instance_id
    public_dns = get_public_dns instance_id
    user = "ec2-user"
    options = '-o "StrictHostKeyChecking no"'
    response = `ssh #{options} #{user}@#{public_dns} free -m 2> /dev/null`
    return nil unless response.match(/(\d+)\s+(\d+)\s+(\d+)/)
    {
      instance_id: instance_id,
      total: $1.to_i,
      used: $2.to_i,
      free: $3.to_i
    } rescue nil
  end
end
