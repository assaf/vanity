require "erb"
require "cgi"

module Vanity
  
  # Render method available to templates (when used by Vanity command line,
  # outside Rails).
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

    # Escape HTML.
    def h(html)
      CGI.escape_html(html)
    end

  end

  # Commands available when running Vanity from the command line (see bin/vanity).
  module Commands
    class << self
      include Render

      # Generate an HTML report.  Outputs to the named file, or stdout with no
      # arguments.
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
