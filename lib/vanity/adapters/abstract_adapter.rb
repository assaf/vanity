module Vanity
  module Adapters

    def self.establish_connection(spec)
      adapter_method = "#{spec[:adapter]}_connection"
      send adapter_method, spec
    end


    class AbstractAdapter
      def active?
        false
      end
      def disconnect!
      end
      def reconnect!
      end
    end
  end
end
