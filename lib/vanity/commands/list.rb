module Vanity
  module Commands
    class << self
      # Lists all experiments and metrics.
      def list
        Vanity.playground.experiments.each do |id, experiment|
          puts "experiment :%-.20s (%-.40s)" % [id, experiment.name]
          if experiment.respond_to?(:alternatives)
            experiment.alternatives.each do |alt|
              hash = experiment.fingerprint(alt)
              puts "  %s: %-40.40s  (%s)" % [alt.name, alt.value, hash]
            end
          end
        end
        Vanity.playground.metrics.each do |id, metric|
          puts "metric :%-.20s (%-.40s)" % [id, metric.name]
        end
      end
    end
  end
end
