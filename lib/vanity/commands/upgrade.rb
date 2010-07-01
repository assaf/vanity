module Vanity
  module Commands
    class << self
      # Upgrade to newer version of Vanity (this usually means doing magic in
      # the database)
      def upgrade
        if Vanity.playground.connection.respond_to?(:redis)
          redis = Vanity.playground.connection.redis
          # Upgrade metrics from 1.3 to 1.4
          keys = redis.keys("metrics:*")
          if keys.empty?
            puts "No metrics to upgrade"
          else
            puts "Updating #{keys.map { |name| name.split(":")[1] }.uniq.length} metrics"
            keys.each do |key|
              redis.renamenx key, "vanity:#{key}"
            end
          end
          # Upgrade experiments from 1.3 to 1.4
          keys = redis.keys("vanity:1:*")
          if keys.empty?
            puts "No experiments to upgrade"
          else
            puts "Updating #{keys.map { |name| name.split(":")[2] }.uniq.length} experiments"
            keys.each do |key|
              redis.renamenx key, key.gsub(":1:", ":experiments:")
            end
          end
        end
      end
    end
  end
end
