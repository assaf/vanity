require 'rails/generators'
require 'rails/generators/migration'

module Vanity
  module Generators
    
    class VanityGenerator < ::Rails::Generators::Base
      namespace 'vanity'
      include ::Rails::Generators::Migration
      source_root File.expand_path('../templates', __FILE__)
      
      def self.next_migration_number(path)
        Time.now.utc.strftime("%Y%m%d%H%M%S")
      end
      
      def create_model_file
        migration_template "vanity_migration.rb", "db/migrate/vanity_migration.rb"
        migration_template "vanity_migration_add_enabled_to_vanity_experiments.rb", "db/migrate/vanity_migration_add_enabled_to_vanity_experiments.rb"
      end
    end
    
  end
end