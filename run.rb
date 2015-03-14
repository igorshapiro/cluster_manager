require 'rubygems'
require 'bundler/setup'
require 'yaml'

require './manager.rb'

# def find_with_available_resources
#
# end
#
# def monitor_resources
#   Thread.new
# end

# launch_instance

Manager.new.run

# monitor_resources
#
# while task = get_task
#   machine = find_with_available_resources
#   machine = create_machine unless machine
#   run task, machine
# end
