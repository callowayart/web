namespace :test do
  desc "test memoization"
  task :memo do
    def fibonacci (n)
      return n if n <= 1
      fibonacci(n - 1) + fibonacci(n - 2)
    end
    
    result = memo "fib", 20 do |key|
      fibonacci(key)
    end

    puts result.to_i == 6765
  end
end
