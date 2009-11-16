module Vanity
  module Rails
    module ConsoleActions
      def index
        render Vanity.template("_report"), content_type: Mime::HTML, layout: true
      end

      def chooses
        exp = Vanity.playground.experiment(params[:e])
        exp.chooses(exp.alternatives[params[:a].to_i].value)
        render partial: Vanity.template("experiment"), locals: { experiment: exp }
      end
    end
  end
end
