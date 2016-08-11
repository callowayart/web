require "yaml"
require "ostruct"

def config
  @value ||= begin
    YAML.load_file("./config.yml")
  end
end

=begin USAGE
puts config.redis.host
puts config.redis.port
=end
