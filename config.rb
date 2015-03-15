require 'yaml'

class Settings
  @@cfg = YAML.load_file('config.yml')

  class << self
    def method_missing(m, *args, &block)
      @@cfg[m.to_s]
    end
  end
end
