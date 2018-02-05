require "vanity/adapters/active_record_adapter"

class AddParticipansUniqueIndexMigration < ActiveRecord::Migration
  # Helper methods to ensure we're connecting to the right database, see
  # https://github.com/assaf/vanity/issues/295.

  def connection
    @connection ||= ActiveRecord::Base.connection
  end
  alias_method :default_connection, :connection

  def with_vanity_connection
    @connection = Vanity::Adapters::ActiveRecordAdapter::VanityRecord.connection
    yield
    @connection = default_connection
  end

  def change
    with_vanity_connection do
      remove_index :vanity_participants, :name => "by_experiment_id_and_identity"
      add_index :vanity_participants, [:experiment_id, :identity], :name => "by_experiment_id_and_alternative", :unique => true
    end
  end
end
