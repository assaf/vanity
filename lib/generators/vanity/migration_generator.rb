require 'rails/generators'
require 'rails/generators/migration'
require 'rails/generators/active_record'

class VanityGenerator < Rails::Generators::Base
  include Rails::Generators::Migration
  source_root File.expand_path('../templates', __dir__)

  def self.next_migration_number(path)
    ::ActiveRecord::Generators::Base.next_migration_number(path)
  end

  def create_migration_file
    migration_template "vanity_migration.rb.erb", destination("vanity_migration.rb"), migration_version: migration_version
    migration_template "add_unique_indexes_migration.rb.erb", destination("add_vanity_unique_indexes.rb"), migration_version: migration_version
    migration_template "add_participants_unique_index_migration.rb.erb", destination("add_participants_unique_index_migration.rb"), migration_version: migration_version
  end

  private

  def destination(name)
    File.join(Rails.root, 'db', 'migrate', name)
  end

  def versioned?
    ActiveRecord::VERSION::MAJOR >= 5
  end

  def migration_version
    "[#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}]" if versioned?
  end
end
