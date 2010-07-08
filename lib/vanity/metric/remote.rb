require "net/http"
require "cgi"

module Vanity
  class Metric

    # Specifies the base URL to use for a remote metric. For example:
    #   metric :sandbox do
    #     remote "http://api.vanitydash.com/metrics/sandbox"
    #   end
    def remote(url = nil)
      @remote_url = URI.parse(url) if url
      @mutex ||= Mutex.new
      extend Remote
      @remote_url
    end

    # To update a remote metric, make a POST request to the metric URL with the
    # content type "application/x-www-form-urlencoded" and the following
    # fields:
    # - The +metric+ identifier,
    # - The +timestamp+ must be RFC 2616 formatted (in Ruby just call +httpdate+
    #   on the Time object),
    # - The +identity+ (optional),
    # - Pass consecutive values using the field +values[]+, or
    # - Set values by their index using +values[0]+, +values[1]+, etc or
    # - Set values by series name using +values[foo]+, +values[bar]+, etc.
    module Remote

      def track!(args = nil)
        return unless @playground.collecting?
        timestamp, identity, values = track_args(args)
        params = ["metric=#{CGI.escape @id.to_s}", "timestamp=#{CGI.escape timestamp.httpdate}"]
        params << "identity=#{CGI.escape identity.to_s}" if identity
        params.concat values.map { |v| "values[]=#{v.to_i}" }
        params << @remote_url.query if @remote_url.query
        @mutex.synchronize do
          @http ||= Net::HTTP.start(@remote_url.host, @remote_url.port)
          @http.request Net::HTTP::Post.new(@remote_url.path, "Content-Type"=>"application/x-www-form-urlencoded"), params.join("&")
        end
      rescue Timeout::Error, StandardError
        @playground.logger.error "Error sending data for metric #{name}: #{$!}"
        @http = nil
      ensure
        call_hooks timestamp, identity, values
      end

      # "Don't worry, be crappy. Revolutionary means you ship and then test."
      # -- Guy Kawazaki

    end
  end
end
