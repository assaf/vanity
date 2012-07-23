require 'rails/generators'
require 'rails/generators/migration'

module Vanity
  module Generators
    
    class UpdateGenerator < ::Rails::Generators::Base
      include ::Rails::Generators::Migration
      source_root File.expand_path('../templates', __FILE__)  
      
      def self.next_migration_number(path)
        Time.now.utc.strftime("%Y%m%d%H%M%S")
      end
      
      desc "Only add the enabled column to the vanity_experiments table."
      def create_model_file
        migration_template "vanity_migration_add_enabled_to_vanity_experiments.rb", "db/migrate/vanity_migration_add_enabled_to_vanity_experiments.rb"
      end
    end
    
  end
end