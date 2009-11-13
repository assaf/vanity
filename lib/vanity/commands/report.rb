require "erb"
require "cgi"

module Vanity
  
  # Render method available in templates (when running outside Rails).
  module Render
    
    # Render the named template.  Used for reporting and the console.
    def render(path, locals = {})
      locals[:playground] = self
      keys = locals.keys
      struct = Struct.new(*keys)
      struct.send :include, Render
      locals = struct.new(*locals.values_at(*keys))
      dir, base = File.split(path)
      path = File.read(File.join(dir, "_#{base}"))
      ERB.new(path, nil, '<').result(locals.instance_eval { binding })
    end

  end

  module Commands
    class << self
      include Render

      # Generate a report with all available tests.  Outputs to the named file,
      # or stdout with no arguments.
      def report(output = nil)
        html = render(Vanity.template("report"))
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
