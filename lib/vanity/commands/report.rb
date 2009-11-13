module Vanity
  module Commands
    class << self

      # Generate a report with all available tests.  Outputs to the named file,
      # or stdout with no arguments.
      def report(output = nil)
        html = Vanity.playground.render("report")
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
