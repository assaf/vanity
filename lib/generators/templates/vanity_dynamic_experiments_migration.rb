class VanityDynamicExperimentsMigration < ActiveRecord::Migration
  def self.up
    create_table :vanity_dynamic_experiments do |t|
      t.string :name
      t.string :description
    end
    add_index :vanity_dynamic_experiments, [:name]

    create_table :vanity_dynamic_experiment_alternatives do |t|
      t.integer :dynamic_experiment_id
      t.string :name
    end
    add_index :vanity_dynamic_experiment_alternatives, [:name]


    create_table :vanity_dynamic_experiment_metrics do |t|
      t.integer :dynamic_experiment_id
      t.integer :metric_id
    end
    add_index :vanity_dynamic_experiment_metrics, :dynamic_experiment_id
    add_index :vanity_dynamic_experiment_metrics, :metric_id
  end

  def self.down
    drop_table :vanity_dynamic_experiments
    drop_table :vanity_dynamic_experiment_alternatives
    drop_table :vanity_dynamic_experiment_metrics

  end
end
