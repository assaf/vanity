module Vanity
  module Adapters
    class << self
      # Creates new connection to underlying datastore and returns suitable
      # adapter (adapter object extends AbstractAdapter and wraps the
      # connection). Vanity.playground.establish_connection uses this.
      #
      # @since 1.4.0
      def establish_connection(spec)
        begin
          require "vanity/adapters/#{spec[:adapter]}_adapter"
        rescue LoadError
          raise "Could not find #{spec[:adapter]} in your load path"
        end
        adapter_method = "#{spec[:adapter]}_connection"
        send adapter_method, spec
      end
    end
  end
end