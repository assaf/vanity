module Vanity
  module Adapters
    class << self
      # Creates new connection to underlying datastore and returns suitable
      # adapter (adapter objects extend AbstractAdapter and wrap the
      # connection).
      #
      # @since 1.4.0
      # @deprecated
      def establish_connection(spec)
        begin
          require "vanity/adapters/#{spec[:adapter]}_adapter"
        rescue LoadError
          raise "Could not find #{spec[:adapter]} in your load path"
        end
        adapter_method = "#{spec[:adapter]}_connection"
        send(adapter_method, spec)
      end
    end
  end
end