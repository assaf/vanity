module Vanity
  module Store
    # @since 1.3.0
    class Mock
      @@hash = {}

      def initialize(options = {})
      end

      def get(key)
        @@hash[key]
      end
      alias :[] :get

      def set(key, value)
        @@hash[key] = value.to_s
      end
      alias :[]= :set

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
        y = get(key)
        y ? YAML.load(y).member?(value.to_s) : false
      end

      def sadd(key, value)
        y = get(key)
        s = Set.new(y ? YAML.load(y) : [])
        s.add value.to_s
        set key, YAML.dump(s.to_a)
      end

      def scard(key)
        y = get(key)
        y ? YAML.load(y).size : 0
      end
    end
  end
end
