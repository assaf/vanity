module Vanity
  # A singleton responsible for determining if the playground should connect
  # to the datastore.
  module Autoconnect
    BLACKLISTED_RAILS_RAKE_TASKS = [
      'about',
      'assets:clean',
      'assets:clobber',
      'assets:environment',
      'assets:precompile',
      'assets:precompile:all',
      'db:create',
      'db:drop',
      'db:fixtures:load',
      'db:migrate',
      'db:migrate:status',
      'db:rollback',
      'db:reset',
      'db:schema:cache:clear',
      'db:schema:cache:dump',
      'db:schema:dump',
      'db:schema:load',
      'db:seed',
      'db:setup',
      'db:structure:dump',
      'db:test:load',
      'db:version',
      'doc:app',
      'log:clear',
      'middleware',
      'notes',
      'notes:custom',
      'rails:template',
      'rails:update',
      'routes',
      'secret',
      'stats',
      'time:zones:all',
      'tmp:clear',
      'tmp:create',
    ]
    ENVIRONMENT_VANITY_DISABLED_FLAG = "VANITY_DISABLED"

    class << self
      def should_connect?
        !environment_disabled? && !in_blacklisted_rake_task?
      end
      alias playground_should_autoconnect? should_connect?

      def schema_relevant?
        current_rake_tasks.any? { |task| task =~ /\Adb:/ }
      end

      def environment_disabled?
        !!ENV[ENVIRONMENT_VANITY_DISABLED_FLAG]
      end

      def in_blacklisted_rake_task?
        !(current_rake_tasks & BLACKLISTED_RAILS_RAKE_TASKS).empty?
      end

      def current_rake_tasks
        ::Rake.application.top_level_tasks
      rescue StandardError
        []
      end
    end
  end
end
