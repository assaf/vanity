module Vanity
  module Templates
    extend self

    # Path to template.
    def template(name)
      File.join(template_directory, name)
    end

    def template_directory
      @template_directory ||= load_paths.find { |dir| File.exists?(dir) }
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
      Templates.template(name)
    end
  end
end
