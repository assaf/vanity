class Vanity::ViewsGenerator < Rails::Generators::Base
  desc "Add copies of the vanity views to your app for customization"

  def create_view_files
    Vanity::ViewsGenerator.source_root(destination_directory)
    directory source_directory, destination_directory
  end

  def destination_directory
    File.join(Rails.root, 'app', 'views', 'vanity')
  end

  def source_directory
    File.join(File.dirname(__FILE__), '..', '..', 'vanity', 'templates')
  end
end
