module Vanity
  module Rails
    # Step 1: Add a new resource in config/routes.rb:
    #   map.vanity "/vanity/:action/:id", :controller=>:vanity
    #
    # Step 2: Create a new experiments controller:
    #   class VanityController < ApplicationController
    #     include Vanity::Rails::Dashboard
    #   end
    #
    # Step 3: Open your browser to http://localhost:3000/vanity
    module Dashboard
      def index
        render Vanity.template("_report"), :content_type=>Mime::HTML, :layout=>true
      end

      def chooses
        exp = Vanity.playground.experiment(params[:e])
        exp.chooses(exp.alternatives[params[:a].to_i].value)
        render :partial=>Vanity.template("experiment"), :locals=>{ :experiment=>exp }
      end
    end
  end
end
