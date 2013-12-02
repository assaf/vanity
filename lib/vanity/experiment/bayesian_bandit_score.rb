module Vanity
  module Experiment
    class Score
      attr_accessor :alts, :best, :base, :least, :choice, :method
    end

    class BayesianBanditScore < Score
      DEFAULT_PROBABILITY = 90

      def initialize(alternatives, outcome)
        @alternatives = alternatives
        @outcome = outcome
        @method = :bayes_bandit_score
      end

      def calculate!(probability=DEFAULT_PROBABILITY)
        # sort by conversion rate to find second best
        @alts = @alternatives.sort_by(&:measure)
        @base = @alts[-2]

        assign_alternatives_bayesian_probability(@alts)

        @least = assign_alternatives_difference(@alts)

        # best alternative is one with highest conversion rate (best shot).
        @best = @alts.last if @alts.last.measure > 0.0
        # choice alternative can only pick best if we have high probability (>90%).
        @choice = outcome_or_best_probability(@alternatives, @outcome, @best, probability)
        self
      end

      protected

      def outcome_or_best_probability(alternatives, outcome, best, probability)
        if outcome
          alternatives[@outcome.id]
        elsif best && best.probability >= probability
          best
        else
          nil
        end
      end

      # Assign each alternative's bayesian probability of being the best
      # alternative to alternative#probability.
      def assign_alternatives_bayesian_probability(alternatives)
        alternative_posteriors = calculate_alternative_posteriors(alternatives)
        alternatives.each_with_index do |alternative, i|
          alternative.probability = 100 * probability_alternative_is_best(alternative_posteriors[i], alternative_posteriors)
        end
      end

      def calculate_alternative_posteriors(alternatives)
        alternatives.map do |alternative|
          x = alternative.converted
          n = alternative.participants
          Rubystats::BetaDistribution.new(x+1, n-x+1)
        end
      end

      def probability_alternative_is_best(alternative_being_examined, all_alternatives)
        Integration.integrate(0, 1, :tolerance=>1e-4) do |z|
          pdf_alternative_is_best(z, alternative_being_examined, all_alternatives)
        end
      end

      def pdf_alternative_is_best(z, alternative_being_examined, all_alternatives)
        # get the pdf for this alternative at z
        pdf = alternative_being_examined.pdf(z)
        # now multiply by the probability that all the other alternatives are lower
        all_alternatives.each do |alternative|
          if alternative != alternative_being_examined
            pdf = pdf * alternative.cdf(z)
          end
        end
        pdf
      end

      def assign_alternatives_difference(alternatives)
        # difference is measured from least performant
        least = alternatives.find { |alternative| alternative.measure > 0 }
        if least
          alternatives.each do |alternative|
            if alternative.measure > least.measure
              alternative.difference = (alternative.measure - least.measure) / least.measure * 100
            end
          end
        end
        least
      end
    end
  end
end
