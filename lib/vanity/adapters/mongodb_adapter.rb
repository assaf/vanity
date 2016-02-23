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
        @options = options.clone
        @options[:database] ||= (@options[:path] && @options[:path].split("/")[1]) || "vanity"
        connect!
      end

      def active?
        !!@mongo
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
        Mongo::Logger.logger = Vanity.logger
        setup_connection(@options)

        @metrics = @mongo["vanity.metrics"]
        @metrics.create unless @mongo.database.collection_names.include?("vanity.metrics")
        @experiments = @mongo["vanity.experiments"]
        @experiments.create unless @mongo.database.collection_names.include?("vanity.experiments")
        @participants = @mongo["vanity.participants"]
        @participants.create unless @mongo.database.collection_names.include?("vanity.participants")
        @participants.indexes.create_many(
          { :key => { :experiment => 1, :identity => 1 }, :unique=>true },
          { :key => { :experiment => 1, :seen => 1 } },
          { :key => { :experiment => 1, :converted => 1 } }
        )

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
        record = @metrics.find(:_id=>metric).limit(1).first
        record && record["last_update_at"]
      end

      def metric_track(metric, timestamp, identity, values)
        inc = {}
        values.each_with_index do |v,i|
          inc["data.#{timestamp.to_date}.#{i}"] = v
        end
        @metrics.find(:_id=>metric).find_one_and_replace(
          {
            "$inc"=>inc,
            "$set"=>{ :last_update_at=>Time.now }
          },
          :upsert=>true
        )
      end

      def metric_values(metric, from, to)
        record = @metrics.find(:_id=>metric).limit(1).first
        data = record && record["data"] || {}
        (from.to_date..to.to_date).map { |date| (data[date.to_s] || {}).values }
      end

      def destroy_metric(metric)
        @metrics.find(:_id=>metric).delete_one
      end


      # -- Experiments --

      def experiment_persisted?(experiment)
        !!@experiments.find(:_id=>experiment).limit(1).first
      end

      def set_experiment_created_at(experiment, time)
        # @experiments.insert_one(:_id=>experiment, :created_at=>time)
        @experiments.find(:_id=>experiment).find_one_and_replace(
          {
            "$setOnInsert"=>{ :created_at=>time }
          },
          :upsert=>true
        )
      end

      def get_experiment_created_at(experiment)
        record = @experiments.find(:_id=>experiment).limit(1).projection(:created_at=>1).first
        record && record["created_at"]
        #Returns nil if either the record or the field doesn't exist
      end

      def set_experiment_completed_at(experiment, time)
        @experiments.find(:_id=>experiment).find_one_and_replace(
          {
            "$set"=>{ :completed_at=>time }
          },
          :upsert=>true
        )
      end

      def get_experiment_completed_at(experiment)
        record = @experiments.find(:_id=>experiment).limit(1).projection(:completed_at=>1).first
        record && record["completed_at"]
      end

      def is_experiment_completed?(experiment)
        !!@experiments.find(:_id=>experiment, :completed_at=>{ "$exists"=>true }).limit(1).first
      end

      def set_experiment_enabled(experiment, enabled)
        @experiments.find(:_id=>experiment).find_one_and_replace(
          {
            "$set"=>{ :enabled=>enabled }
          },
          :upsert=>true
        )
      end

      def is_experiment_enabled?(experiment)
        record = @experiments.find(:_id=>experiment).limit(1).projection(:enabled=>1).first
        if Vanity.configuration.experiments_start_enabled
          record == nil || record["enabled"] != false
        else
          record && record["enabled"] == true
        end
      end

      def ab_counts(experiment, alternative)
        record = @experiments.find(:_id=>experiment ).limit(1).projection(:conversions=>1).first
        conversions = record && record["conversions"]
        { :participants => @participants.find({ :experiment=>experiment, :seen=>alternative }).count,
          :converted    => @participants.find({ :experiment=>experiment, :converted=>alternative }).count,
          :conversions  => conversions && conversions[alternative.to_s] || 0 }
      end

      def ab_show(experiment, identity, alternative)
        @participants.find(:experiment=>experiment, :identity=>identity).find_one_and_replace(
          {
            "$set"=>{ :show=>alternative }
          },
          :upsert=>true
        )
      end

      def ab_showing(experiment, identity)
        participant = @participants.find(:experiment=>experiment, :identity=>identity).limit(1).projection(:show=>1).first
        participant && participant["show"]
      end

      def ab_not_showing(experiment, identity)
        @participants.find(:experiment=>experiment, :identity=>identity).find_one_and_replace(
          {
            "$unset"=> { :show => "" }
          },
          :upsert=>true
        )
      end

      def ab_add_participant(experiment, alternative, identity)
        @participants.find(:experiment=>experiment, :identity=>identity).find_one_and_replace(
          {
            "$push"=>{ :seen=>alternative }
          },
          :upsert=>true
        )
      end

      # Determines if a participant already has seen this alternative in this experiment.
      def ab_seen(experiment, identity, alternative)
        participant = @participants.find(:experiment=>experiment, :identity=>identity).limit(1).projection(:seen=>1).first
        participant && participant["seen"].first == alternative.id
      end

      # Returns the participant's seen alternative in this experiment, if it exists
      def ab_assigned(experiment, identity)
        participant = @participants.find(:experiment=>experiment, :identity=>identity).limit(1).projection(:seen=>1).first
        participant && participant["seen"].first
      end

      def ab_add_conversion(experiment, alternative, identity, count = 1, implicit = false)
        if implicit
          @participants.find(:experiment=>experiment, :identity=>identity).find_one_and_replace(
            {
              "$push"=>{ :seen=>alternative }
            },
            :upsert=>true
          )
        else
          participating = @participants.find(:experiment=>experiment, :identity=>identity, :seen=>alternative).limit(1).first
        end

        if implicit || participating
          @participants.find(:experiment=>experiment, :identity=>identity).find_one_and_replace(
            {
              "$push"=>{ :converted=>alternative }
            },
            :upsert=>true
          )
        end

        @experiments.find(:_id=>experiment).find_one_and_replace(
          {
            "$inc"=>{ "conversions.#{alternative}"=>count }
          },
          :upsert=>true
        )
      end

      def ab_get_outcome(experiment)
        experiment = @experiments.find(:_id=>experiment).limit(1).projection(:outcome=>1).first
        experiment && experiment["outcome"]
      end

      def ab_set_outcome(experiment, alternative = 0)
        @experiments.find(:_id=>experiment).find_one_and_replace(
          {
            "$set"=>{ :outcome=>alternative }
          },
          :upsert=>true
        )
      end

      def destroy_experiment(experiment)
        @experiments.find(:_id=>experiment).delete_one
        @participants.find(:experiment=>experiment).delete_many
      end

      private

      def setup_connection(options)
        options[:user] = options[:username] if options[:username]

        hosts = options.delete(:hosts) || [options.delete(:host)]
        hosts.map! { |host| "#{host}:#{options.delete(:port)}" }

        @mongo = Mongo::Client.new(
          hosts,
          options
        )
      end
    end
  end
end
