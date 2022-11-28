require "yaml"

module Vanity
  module SafeYAML
    begin
      YAML.safe_load("---", permitted_classes: [])
    rescue ArgumentError
      SUPPORTS_PERMITTED_CLASSES = false
    else
      SUPPORTS_PERMITTED_CLASSES = true
    end

    def self.load(payload)
      if SUPPORTS_PERMITTED_CLASSES
        YAML.safe_load(payload, permitted_classes: [], permitted_symbols: [], aliases: true)
      else
        YAML.safe_load(payload, [], [], true)
      end
    end
  end
end
