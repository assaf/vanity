module Vanity
  module Adapters
    class << self
      # Creates new connection to MongoDB and returns MongoAdapter.
      #
      # @since 1.4.0
      def mongo_connection(spec)
        require "mongo"
        MongodbAdapter.new(spec)
      end
      alias :mongodb_connection :mongo_connection
    end

    # MongoDB adapter.
    #
    # @since 1.4.0
    class MongodbAdapter < AbstractAdapter
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

      def active?
        @mongo.connected?
      end

      def disconnect!
        @mongo.close rescue nil if @mongo
        @metrics, @experiments = nil
        @mongo = nil
      end

      def reconnect!
        disconnect!
        connect!
      end

      def connect!
        @mongo ||= setup_connection(@options)
        @mongo.connect
        database = @mongo.db(@options[:database])
        database.authenticate @options[:username], @options[:password], true if @options[:username]
        @metrics = database.collection("vanity.metrics")
        @experiments = database.collection("vanity.experiments")
        @participants = database.collection("vanity.participants")
        @participants.create_index [[:experiment, 1], [:identity, 1]], :unique=>true
        @participants.create_index [[:experiment, 1], [:seen, 1]]
        @participants.create_index [[:experiment, 1], [:converted, 1]]
        @mongo
      end

      def to_s
        userinfo = @options.values_at(:username, :password).join(":") if @options[:username]
        URI::Generic.build(:scheme=>"mongodb", :userinfo=>userinfo, :host=>(@mongo.host || @options[:host]), :port=>(@mongo.port || @options[:port]), :path=>"/#{@options[:database]}").to_s
      end

      def flushdb
        @metrics.drop
        @experiments.drop
        @participants.drop
      end
      

      # -- Metrics --
      
      def get_metric_last_update_at(metric)
        record = @metrics.find_one(:_id=>metric)
        record && record["last_update_at"]
      end

      def metric_track(metric, timestamp, identity, values)
        inc = {}
        values.each_with_index do |v,i|
          inc["data.#{timestamp.to_date}.#{i}"] = v
        end
        @metrics.update({ :_id=>metric }, { "$inc"=>inc, "$set"=>{ :last_update_at=>Time.now } }, :upsert=>true)
      end

      def metric_values(metric, from, to)
        record = @metrics.find_one(:_id=>metric)
        data = record && record["data"] || {}
        (from.to_date..to.to_date).map { |date| (data[date.to_s] || {}).values }
      end

      def destroy_metric(metric)
        @metrics.remove :_id=>metric
      end
      

      # -- Experiments --
      
      def set_experiment_enabled(experiment, enabled)
        @experiments.update({ :_id=>experiment }, { "$set"=>{ :enabled=>enabled } }, :upsert=>true)
      end

      def is_experiment_enabled?(experiment)
        record = @experiments.find_one({ :_id=>experiment}, { :fields=>[:enabled] })
        record && record["enabled"] == true
      end
     
      def set_experiment_created_at(experiment, time)
        @experiments.insert :_id=>experiment, :created_at=>time
      end

      def get_experiment_created_at(experiment)
        record = @experiments.find_one({ :_id=>experiment }, { :fields=>[:created_at] })
        record && record["created_at"]
        #Returns nil if either the record or the field doesn't exist
      end

      def set_experiment_completed_at(experiment, time)
        @experiments.update({ :_id=>experiment }, { "$set"=>{ :completed_at=>time } }, :upsert=>true)
      end

      def get_experiment_completed_at(experiment)
        record = @experiments.find_one({ :_id=>experiment }, { :fields=>[:completed_at] })
        record && record["completed_at"]
      end

      def is_experiment_completed?(experiment)
        !!@experiments.find_one(:_id=>experiment, :completed_at=>{ "$exists"=>true })
      end

      def ab_counts(experiment, alternative)
        record = @experiments.find_one({ :_id=>experiment }, { :fields=>[:conversions] })
        conversions = record && record["conversions"]
        { :participants => @participants.find({ :experiment=>experiment, :seen=>alternative }).count,
          :converted    => @participants.find({ :experiment=>experiment, :converted=>alternative }).count,
          :conversions  => conversions && conversions[alternative.to_s] || 0 }
      end

      def ab_show(experiment, identity, alternative)
        @participants.update({ :experiment=>experiment, :identity=>identity }, { "$set"=>{ :show=>alternative } }, :upsert=>true)
      end

      def ab_showing(experiment, identity)
        participant = @participants.find_one({ :experiment=>experiment, :identity=>identity }, { :fields=>[:show] })
        participant && participant["show"]
      end

      def ab_not_showing(experiment, identity)
        @participants.update({ :experiment=>experiment, :identity=>identity }, { "$unset"=>:show })
      end

      def ab_add_participant(experiment, alternative, identity)
        @participants.update({ :experiment=>experiment, :identity=>identity }, { "$push"=>{ :seen=>alternative } }, :upsert=>true)
      end

      def ab_add_conversion(experiment, alternative, identity, count = 1, implicit = false)
        if implicit
          @participants.update({ :experiment=>experiment, :identity=>identity }, { "$push"=>{ :seen=>alternative } }, :upsert=>true)
        else
          participating = @participants.find_one(:experiment=>experiment, :identity=>identity, :seen=>alternative)
        end
        @participants.update({ :experiment=>experiment, :identity=>identity }, { "$push"=>{ :converted=>alternative } }, :upsert=>true) if implicit || participating
        @experiments.update({ :_id=>experiment }, { "$inc"=>{ "conversions.#{alternative}"=>count } }, :upsert=>true)
      end

      def ab_get_outcome(experiment)
        experiment = @experiments.find_one({ :_id=>experiment }, { :fields=>[:outcome] })
        experiment && experiment["outcome"]
      end

      def ab_set_outcome(experiment, alternative = 0)
        @experiments.update({ :_id=>experiment }, { "$set"=>{ :outcome=>alternative } }, :upsert=>true)
      end

      def destroy_experiment(experiment)
        @experiments.remove :_id=>experiment
        @participants.remove :experiment=>experiment
      end
    end
  end
end
