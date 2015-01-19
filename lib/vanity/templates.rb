module Vanity
  class Templates
    def initialize
      @template_directory = load_paths.find { |dir| File.exists?(dir) }
    end

    # Path to template.
    def path(name)
      File.join(@template_directory, name)
    end

    private

    def load_paths
      [Vanity.playground.custom_templates_path, gem_templates_path].compact
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
