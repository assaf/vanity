class VanityMigrationAddVanityMetricCountsTable < ActiveRecord::Migration
  def self.up
    create_table :vanity_metric_counts do |t|
      t.integer :vanity_experiment_id
      t.integer :alternative
      t.string :metric
      t.integer :count
    end
    add_index :vanity_metric_counts, [:vanity_experiment_id, :alternative, :metric], :name => "by_experiment_id_and_alternative_and_metric"
  end
  
  def self.down
    drop_table :vanity_metric_counts
  end
end
