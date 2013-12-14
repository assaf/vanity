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
	setup_connection(options)
	@options = options.clone
	@options[:database] ||= (@options[:path] && @options[:path].split("/")[1]) || "vanity"
	connect!
      end

      def setup_connection(options = {})
	if options[:hosts]
	  args = (options[:hosts].map{|host| [host, options[:port]] } << {:connect => false})
	  @mongo = Mongo::ReplSetConnection.new(*args)
	else
	  @mongo = Mongo::Connection.new(options[:host], options[:port], :connect => false)
	end
	@mongo
      end

      def is_experiment_completed?(experiment)
	!!@experiments.find_one(:_id=>experiment, :completed_at=>{ "$exists"=>true })
      end
    end
  end
end
