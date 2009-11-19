module ActionController
  class TestCase
    alias :setup_controller_request_and_response_without_vanity :setup_controller_request_and_response
    # Sets Vanity.context to the current controller, so you can do things like:
    #   experiment(:simple).chooses(:green)
    def setup_controller_request_and_response
      setup_controller_request_and_response_without_vanity 
      Vanity.context = @controller
    end
  end
end
