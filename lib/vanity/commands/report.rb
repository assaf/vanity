require "erb"
require "cgi"

module Vanity
  module Commands
    class << self

      # Generate a report with all available tests.  Outputs to the named file,
      # or stdout with no arguments.
      def report(output = nil)
        require "erb"
        erb = ERB.new(File.read("lib/vanity/report.erb"), nil, '<')
        experiments = Vanity.playground.experiments
        html = erb.result(binding)
        if output
          File.open output, 'w' do |file|
            file.write html
          end
          puts "New report available in #{output}"
        else
          $stdout.write html
        end
      end

    end
  end
end
