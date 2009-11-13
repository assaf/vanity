module Vanity
  module Rails
    module ConsoleActions
      def index
        render Vanity.template("_report"), content_type: Mime::HTML, layout: true
      end

      def chooses
        experiment(params[:e]).chooses(experiment(params[:e]).alternatives[params[:a].to_i].value)
        redirect_to :back
      end
    end
  end
end
