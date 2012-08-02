require 'rails/generators'
require 'rails/generators/migration'

  class VanityGenerator < ::Rails::Generators::Base
    include ::Rails::Generators::Migration
    source_root File.expand_path('../templates', __FILE__)
    
    def self.next_migration_number(path)
      Time.now.utc.strftime("%Y%m%d%H%M%S")
    end
    
    def create_model_file
      migration_template "vanity_migration.rb", "db/migrate/vanity_migration.rb"
      migration_template "vanity_migration_add_enabled_to_vanity_experiments.rb", "db/migrate/vanity_migration_add_enabled_to_vanity_experiments.rb"
      migration_template "vanity_migration_add_vanity_metric_counts_table.rb","db/migrate/vanity_migration_add_vanity_metric_counts_table.rb"
    end
end
