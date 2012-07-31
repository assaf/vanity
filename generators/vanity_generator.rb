class VanityGenerator < Rails::Generator::Base
  def manifest
    record do |m|
      m.migration_template 'vanity_migration.rb', 'db/migrate',
        :migration_file_name => "vanity_migration"
      m.migration_template 'vanity_migration_add_enabled_to_vanity_experiments.rb', 'db/migrate',
        :migration_file_name => "db/migrate/vanity_migration_add_enabled_to_vanity_experiments.rb"
      m.migration_template 'vanity_migration_add_vanity_metric_counts_table.rb', 'db/migrate',
        :migration_file_name => "db/migrate/vanity_migration_add_vanity_metric_counts_table.rb"
    end
  end
end
