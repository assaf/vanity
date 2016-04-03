module Vanity
  module Adapters
    class << self
      # Creates new connection to underlying datastore and returns suitable
      # adapter (adapter object extends AbstractAdapter and wraps the
      # connection).
      #
      # @since 1.4.0
      def establish_connection(spec)
        return unless Autoconnect.should_connect? ||
          (Autoconnect.schema_relevant? && spec[:adapter].to_s == 'active_record')

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