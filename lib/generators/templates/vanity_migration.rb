class VanityMigration < ActiveRecord::Migration
  # Helper methods to ensure we're connecting to the right database, see
  # https://github.com/assaf/vanity/issues/295.

  def connection
    @connection ||= ActiveRecord::Base.connection
  end
  alias_method :default_connection, :connection

  def with_vanity_connection
    @connection = Vanity::Adapters::ActiveRecordAdapter::VanityRecord.connection
    yield
    @connection = default_connection
  end

  def up
    with_vanity_connection do
      create_table :vanity_metrics do |t|
        t.string :metric_id
        t.datetime :updated_at
      end
      add_index :vanity_metrics, [:metric_id]

      create_table :vanity_metric_values do |t|
        t.integer :vanity_metric_id
        t.integer :index
        t.integer :value
        t.string :date
      end
      add_index :vanity_metric_values, [:vanity_metric_id, :date]

      create_table :vanity_experiments do |t|
        t.string :experiment_id
        t.integer :outcome
        t.boolean :enabled
        t.datetime :created_at
        t.datetime :completed_at
      end
      add_index :vanity_experiments, [:experiment_id]

      create_table :vanity_conversions do |t|
        t.integer :vanity_experiment_id
        t.integer :alternative
        t.integer :conversions
      end
      add_index :vanity_conversions, [:vanity_experiment_id, :alternative], :name => "by_experiment_id_and_alternative"

      create_table :vanity_participants do |t|
        t.string :experiment_id
        t.string :identity
        t.integer :shown
        t.integer :seen
        t.integer :converted
        t.timestamps null: false
      end
      add_index :vanity_participants, [:experiment_id]
      add_index :vanity_participants, [:experiment_id, :identity], :name => "by_experiment_id_and_identity"
      add_index :vanity_participants, [:experiment_id, :shown], :name => "by_experiment_id_and_shown"
      add_index :vanity_participants, [:experiment_id, :seen], :name => "by_experiment_id_and_seen"
      add_index :vanity_participants, [:experiment_id, :converted], :name => "by_experiment_id_and_converted"
    end
  end

  def down
    with_vanity_connection do
      drop_table :vanity_metrics
      drop_table :vanity_metric_values
      drop_table :vanity_experiments
      drop_table :vanity_conversions
      drop_table :vanity_participants
    end
  end
end
