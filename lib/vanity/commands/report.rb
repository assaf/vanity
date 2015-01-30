require "erb"
require "cgi"

module Vanity

  # Render method available to templates (when used by Vanity command line,
  # outside Rails).
  module Render

    # Render the named template. Used for reporting and the dashboard.
    def render(path_or_options, locals = {})
      if path_or_options.respond_to?(:keys)
        render_erb(
          path_or_options[:file] || path_or_options[:partial],
          path_or_options[:locals]
        )
      else
        render_erb(path_or_options, locals)
      end
    end

    # Escape HTML.
    def vanity_h(html)
      CGI.escapeHTML(html.to_s)
    end

    def vanity_html_safe(text)
      text
    end

    class ProxyEmpty < String
      def method_missing(method, *args, &block); self.class.new end
    end

    # prevent certain url helper methods from failing so we can run erb templates outside of rails for reports.
    def method_missing(method, *args, &block)
      %w(url_for flash).include?(method.to_s) ? ProxyEmpty.new : super
    end

    # Dumbed down from Rails' simple_format.
    def vanity_simple_format(text, options={})
      open = "<p #{options.map { |k,v| "#{k}=\"#{CGI.escapeHTML v}\"" }.join(" ")}>"
      text = open + text.gsub(/\r\n?/, "\n").   # \r\n and \r -> \n
        gsub(/\n\n+/, "</p>\n\n#{open}").       # 2+ newline  -> paragraph
        gsub(/([^\n]\n)(?=[^\n])/, '\1<br />') + # 1 newline   -> br
        "</p>"
    end

    protected

    def render_erb(path, locals = {})
      locals[:playground] = self
      keys = locals.keys
      struct = Struct.new(*keys)
      struct.send :include, Render
      locals = struct.new(*locals.values_at(*keys))
      dir, base = File.split(path)
      path = File.join(dir, partialize(base))
      erb = ERB.new(File.read("#{path}.erb"), nil, '<>')
      erb.filename = path
      erb.result(locals.instance_eval { binding })
    end

    def partialize(template_name)
      if template_name[0] != '_'
        "_#{template_name}"
      else
        template_name
      end
    end
  end

  # Commands available when running Vanity from the command line (see bin/vanity).
  module Commands
    class << self
      include Render

      # Generate an HTML report. Outputs to the named file, or stdout with no
      # arguments.
      def report(output = nil)
        html = render(Vanity.template("report"),
          :experiments=>Vanity.playground.experiments,
          :experiments_persisted=>Vanity.playground.experiments_persisted?,
          :metrics=>Vanity.playground.metrics
        )
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
