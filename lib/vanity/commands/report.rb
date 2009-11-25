require "erb"
require "cgi"

module Vanity
  
  # Render method available to templates (when used by Vanity command line,
  # outside Rails).
  module Render
    
    # Render the named template.  Used for reporting and the dashboard.
    def render(path, locals = {})
      locals[:playground] = self
      keys = locals.keys
      struct = Struct.new(*keys)
      struct.send :include, Render
      locals = struct.new(*locals.values_at(*keys))
      dir, base = File.split(path)
      path = File.join(dir, "_#{base}")
      erb = ERB.new(File.read(path), nil, '<>')
      erb.filename = path
      erb.result(locals.instance_eval { binding })
    end

    # Escape HTML.
    def h(html)
      CGI.escapeHTML(html)
    end

    # Dumbed down from Rails' simple_format.
    def simple_format(text, options={})
      open = "<p #{options.map { |k,v| "#{k}=\"#{CGI.escapeHTML v}\"" }.join(" ")}>"
      text = open + text.gsub(/\r\n?/, "\n").   # \r\n and \r -> \n
        gsub(/\n\n+/, "</p>\n\n#{open}").       # 2+ newline  -> paragraph
        gsub(/([^\n]\n)(?=[^\n])/, '\1<br />') + # 1 newline   -> br
        "</p>"
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
