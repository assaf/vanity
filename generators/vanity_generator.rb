class VanityGenerator < Rails::Generator::Base
  def manifest
    record do |m|
      m.migration_template 'vanity_migration.rb', 'db/migrate',
        :migration_file_name => "vanity_migration"
    end
  end
end
