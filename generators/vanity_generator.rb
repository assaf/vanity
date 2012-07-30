class VanityGenerator < Rails::Generator::Base
  def manifest
    record do |m|
      m.migration_template 'vanity_migration.rb', 'db/migrate',
        :migration_file_name => "vanity_migration"
      m.migration_template 'vanity_migration_add_enabled_to_vanity_experiments.rb', 'db/migrate',
        :migration_file_name => "db/migrate/vanity_migration_add_enabled_to_vanity_experiments.rb"
    end
  end
end
