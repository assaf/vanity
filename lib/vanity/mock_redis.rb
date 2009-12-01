module Vanity
  # The Redis you should never use in production.
  class MockRedis
    @@hash = {}

    def initialize(options = {})
    end

    def [](key)
      @@hash[key]
    end

    def []=(key, value)
      @@hash[key] = value.to_s
    end

    def del(*keys)
      keys.flatten.each do |key|
        @@hash.delete key
      end
    end

    def setnx(key, value)
      @@hash[key] = value.to_s unless @@hash.has_key?(key)
    end

    def incr(key)
      @@hash[key] = (@@hash[key].to_i + 1).to_s
    end

    def incrby(key, value)
      @@hash[key] = (@@hash[key].to_i + value).to_s
    end

    def mget(keys)
      @@hash.values_at(*keys)
    end

    def exists(key)
      @@hash.has_key?(key)
    end

    def keys(pattern)
      regexp = Regexp.new(pattern.split("*").map { |r| Regexp.escape(r) }.join(".*"))
      @@hash.keys.select { |key| key =~ regexp }
    end

    def flushdb
      @@hash.clear
    end

    def sismember(key, value)
      case set = @@hash[key]
      when nil ; false
      when Set ; set.member?(value)
      else fail "Not a set"
      end
    end

    def sadd(key, value)
      case set = @@hash[key]
      when nil ; @@hash[key] = Set.new([value])
      when Set ; set.add value
      else fail "Not a set"
      end
    end

    def scard(key)
      case set = @@hash[key]
      when nil ; 0
      when Set ; set.size
      else fail "Not a set"
      end
    end
  end
end
