module Vanity
  module Adapters
    class << self
      # Creates new connection to MongoDB and returns MongoidAdapter.
      #
      # @since 1.9.0
      def mongoid_connection(spec)
	require "mongoid"
	MongoidAdapter.new(spec)
      end
    end

    # Mongoid adapter for Mongo.
    #
    # @since 1.9.0
    class MongoidAdapter < MongodbAdapter
      attr_reader :mongo

      def initialize(options)
	if File.exists?("config/mongoid.yml")
	  env = ENV["RACK_ENV"] || ENV["RAILS_ENV"] || "development"
	  mongoid_options = YAML.load(ERB.new(File.read("config/mongoid.yml")).result)[env]
	  mongoid_options = mongoid_options.inject({}) { |h,kv| h[kv.first.to_sym] = kv.last ; h }
	  options.merge!(mongoid_options)
	end

	setup_connection(options)
	@options = options.clone
	@options[:database] ||= (@options[:path] && @options[:path].split("/")[1]) || "vanity"
	connect!
      end

      def setup_connection(options = {})
	if options[:hosts]
	  @mongo = Mongo::ReplSetConnection.new(*options[:hosts])
	else
	  @mongo = Mongo::Connection.new(options[:host], options[:port], :connect => false)
	end
	@mongo
      end

      def is_experiment_completed?(experiment)
	experiment = @experiments.find_one(:_id=>experiment)
	!!(experiment && experiment['completed_at'])
      end
    end
  end
end
