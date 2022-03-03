module Vanity
  module Commands
    class << self
      # Lists all experiments and metrics.
      def list
        Vanity.playground.experiments.each do |id, experiment|
          puts format("experiment :%-.20s (%-.40s)", id, experiment.name)
          next unless experiment.respond_to?(:alternatives)

          experiment.alternatives.each do |alt|
            hash = experiment.fingerprint(alt)
            puts format("  %s: %-40.40s  (%s)", alt.name, alt.value, hash)
          end
        end
        Vanity.playground.metrics.each do |id, metric|
          puts format("metric :%-.20s (%-.40s)", id, metric.name)
        end
      end
    end
  end
end
