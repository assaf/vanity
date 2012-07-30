class VanityMigrationAddEnabledToVanityExperiments < ActiveRecord::Migration
  def self.up
    add_column :vanity_experiments, :enabled, :boolean
  end
  
  def self.down
    remove_column :vanity_experiments, :enabled
  end
end