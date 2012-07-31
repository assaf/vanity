class VanityMigration < ActiveRecord::Migration
  def self.up
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
    add_index :vanity_metric_values, [:vanity_metric_id]

    create_table :vanity_experiments do |t|
      t.string :experiment_id
      t.integer :outcome
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
    end
    add_index :vanity_participants, [:experiment_id]
    add_index :vanity_participants, [:experiment_id, :identity], :name => "by_experiment_id_and_identity"
    add_index :vanity_participants, [:experiment_id, :shown], :name => "by_experiment_id_and_shown"
    add_index :vanity_participants, [:experiment_id, :seen], :name => "by_experiment_id_and_seen"
    add_index :vanity_participants, [:experiment_id, :converted], :name => "by_experiment_id_and_converted"
  end

  def self.down
    drop_table :vanity_metrics
    drop_table :vanity_metric_values
    drop_table :vanity_experiments
    drop_table :vanity_conversions
    drop_table :vanity_participants
  end
end
