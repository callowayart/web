require "redis"

def redis
  @redis ||= begin
    c = config['redis']
    Redis.new(
      :host => c['host'],
      :port => c['port']
    )
  end
end

=begin USAGE example
def fibonacci (n)
  return n if n <= 1
  fibonacci(n - 1) + fibonacci(n - 2)
end

result = memo "fib", 35 do |key|
  fibonacci(key)
end
puts result
=end
