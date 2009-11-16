require "date"

module Vanity
  module Experiment

    class Usage < Base
      class << self

        def friendly_name
          "Usage"
        end

      end

      def initialize(*args) #:nodoc:
        super
        @milestones = []
      end

      def measure(&block)
        @measure = block
      end

      def results
        @measure.call created_at.to_date, Date.today
      end

      def milestones
        @milestones
      end

      def milestone(label)
        id = label.to_s.downcase.gsub(/\s/, "_")
        redis.setnx key("milestones:#{id}:label"), label
        redis.setnx key("milestones:#{id}:created_at"), Time.now.to_i
        @milestones << [label, Time.at(redis[key("milestones:#{id}:created_at")].to_i)]
      end

      def reset!
        super
        redis.keys(key("milestones:*")).each { |key| redis.del key }
      end
    end

  end

  module Definition
    # Define a usage experiment with the given name.  For example:
    #   usage "Engagement" do
    #     milestone "Added smiley faces"
    #   end
    def usage(name, &block)
      define name, :usage, &block
    end
  end
end
