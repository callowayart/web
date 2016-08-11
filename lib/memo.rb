
def memo (namespace, key, &block)
  ns_key = "#{namespace}:#{key}"
  got = redis.get(ns_key)
  if got
    return got
  else
    result = yield(key)
    redis.set(ns_key, result, ex: 1)
    return result
  end
end
