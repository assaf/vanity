module Vanity
  class Templates
    def initialize
      @template_directory = determine_template_directory
    end

    # Path to template.
    def path(name)
      File.join(@template_directory, name)
    end

    private

    def determine_template_directory
      if custom_template_path_valid?
        Vanity.playground.custom_templates_path
      else
        gem_templates_path
      end
    end

    # Check to make sure we set a custome path, it exists, and there are non-
    # dotfiles in the directory.
    def custom_template_path_valid?
      Vanity.playground.custom_templates_path &&
        File.exist?(Vanity.playground.custom_templates_path) &&
        !Dir[File.join(Vanity.playground.custom_templates_path, '*')].empty?
    end

    def gem_templates_path
      File.expand_path(File.join(File.dirname(__FILE__), 'templates'))
    end
  end

  class << self
    def template(name)
      @templates ||= Templates.new
      @templates.path(name)
    end
  end
end
