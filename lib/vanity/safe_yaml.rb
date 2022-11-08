require "yaml"

module Vanity
  module SafeYAML
    begin
      YAML.safe_load("---", permitted_classes: [])
    rescue ArgumentError
      def self.load(payload)
        YAML.safe_load(payload, [], [], true)
      end
    else
      def self.load(payload)
        YAML.safe_load(payload, permitted_classes: [], permitted_symbols: [], aliases: true)
      end
    end
  end
end
