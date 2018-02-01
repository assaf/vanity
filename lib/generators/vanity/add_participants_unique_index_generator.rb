require 'rails/generators'
require 'rails/generators/migration'

class Vanity::AddParticipantsUniqueIndexGenerator < Rails::Generators::Base
  include Rails::Generators::Migration
  source_root File.expand_path('../../templates', __FILE__)

  def self.next_migration_number(path)
    Time.now.utc.strftime("%Y%m%d%H%M%S")
  end

  def create_model_file
    migration_template "add_participants_unique_index_migration.rb", "db/migrate/add_participants_unique_index_migration.rb"
  end
end
