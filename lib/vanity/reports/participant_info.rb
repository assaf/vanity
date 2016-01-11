module Vanity
  module Reports
    module ParticipantInfo
      # Returns an array of all experiments this participant is involved in, with their assignment.
      #  This is done as an array of arrays [[<experiment_1>, <assignment_1>], [<experiment_2>, <assignment_2>]], sorted by experiment name, so that it will give a consistent string
      #  when converted to_s (so could be used for caching, for example)
      def participant_info(participant_id)
        participant_array = []
        experiments.values.sort_by(&:name).each do |e|
          index = connection.ab_assigned(e.id, participant_id)
          if index
            participant_array << [e, e.alternatives[index.to_i]]
          end
        end
        participant_array
      end
    end
  end
end