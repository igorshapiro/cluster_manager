require './ec2'

class Manager
  def initialize
    @ec2 = EC2.new
  end

  def run
    @ec2.launch_instance
  end
end
