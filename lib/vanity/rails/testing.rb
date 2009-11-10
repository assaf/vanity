module ActionController #:nodoc:
  class TestCase
    alias :setup_controller_request_and_response_without_vanity :setup_controller_request_and_response
    def setup_controller_request_and_response
      setup_controller_request_and_response_without_vanity 
      Vanity.context = @request
    end
  end
end
