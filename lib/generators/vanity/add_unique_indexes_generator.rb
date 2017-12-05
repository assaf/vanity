require 'rails/generators'
require 'rails/generators/migration'

class Vanity::AddUniqueIndexesGenerator < Rails::Generators::Base
  include Rails::Generators::Migration
  source_root File.expand_path('../../templates', __FILE__)

  def self.next_migration_number(path)
    Time.now.utc.strftime("%Y%m%d%H%M%S")
  end

  def create_model_file
    migration_template "add_unique_indexes_migration.rb", "db/migrate/add_vanity_unique_indexes.rb"
  end
end
