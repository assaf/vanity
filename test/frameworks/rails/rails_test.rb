require "test_helper"

describe "deprecated Rails load_path and deprecated connection configuration" do
  it "load_path" do
    assert_equal "./experiments", load_rails("", <<~RB)
      $stdout << Vanity.playground.load_path
    RB
  end

  it "settable load_path" do
    assert_equal "predictions", load_rails(%{\nVanity.playground.load_path = "predictions"\n}, <<~RB)
      $stdout << Vanity.playground.load_path
    RB
  end

  it "absolute load_path" do
    Dir.mktmpdir do |dir|
      assert_equal dir, load_rails(%{\nVanity.playground.load_path = "#{dir}"\n}, <<~RB)
        $stdout << Vanity.playground.load_path
      RB
    end
  end

  if ENV['DB'] == 'redis'
    it "default connection" do
      assert_equal "redis://127.0.0.1:6379/0", load_rails("", <<~RB)
        $stdout << Vanity.playground.connection
      RB
    end

    it "connection from string" do
      assert_equal "redis://192.168.1.1:6379/5", load_rails(%{\nVanity.playground.establish_connection "redis://192.168.1.1:6379/5"\n}, <<~RB)
        $stdout << Vanity.playground.connection
      RB
    end

    it "connection from yaml" do
      FileUtils.mkpath "tmp/config"
      File.write("tmp/config/vanity.yml", <<~YML)
        production:
          adapter: redis
          host: somehost
          database: 15
      YML
      assert_equal "redis://somehost:6379/15", load_rails("", <<~RB, "production")
        $stdout << Vanity.playground.connection
      RB
    ensure
      File.unlink "tmp/config/vanity.yml"
    end

    it "connection from yaml url" do
      FileUtils.mkpath "tmp/config"
      File.write("tmp/config/vanity.yml", <<~YML)
        production: redis://somehost/15
      YML
      assert_equal "redis://somehost:6379/15", load_rails("", <<~RB, "production")
        $stdout << Vanity.playground.connection
      RB
    ensure
      File.unlink "tmp/config/vanity.yml"
    end

    it "connection from yaml with erb" do
      FileUtils.mkpath "tmp/config"
      # Pass storage URL through environment like heroku does
      @original_redis_url = ENV["REDIS_URL"]
      ENV["REDIS_URL"] = "redis://somehost:6379/15"
      File.write("tmp/config/vanity.yml", <<~YML)
        production: <%= ENV['REDIS_URL'] %>
      YML
      assert_equal "redis://somehost:6379/15", load_rails("", <<~RB, "production")
        $stdout << Vanity.playground.connection
      RB
    ensure
      ENV["REDIS_URL"] = @original_redis_url
      File.unlink "tmp/config/vanity.yml"
    end

    it "connection from redis yml" do
      FileUtils.mkpath "tmp/config"
      yml = File.open("tmp/config/redis.yml", "w")
      yml << "production: internal.local:6379\n"
      yml.flush
      assert_match %r{redis://internal.local:6379/0\Z}, load_rails("", <<~RB)
        $stdout << Vanity.playground.connection
      RB
    ensure
      File.unlink yml.path
    end
  end

  if ENV['DB'] == 'mongo'
    it "mongo connection from yaml" do
      FileUtils.mkpath "tmp/config"
      File.write("tmp/config/vanity.yml", <<~YML)
        mongodb:
          adapter: mongodb
          host: localhost
          port: 27017
          database: vanity_test
      YML

      assert_equal "mongodb://localhost:27017/vanity_test", load_rails("", <<~RB, "mongodb")
        $stdout << Vanity.playground.connection
      RB
    ensure
      File.unlink "tmp/config/vanity.yml"
    end

    unless ENV['CI'] == 'true' # See http://docs.travis-ci.com/user/environment-variables/#Default-Environment-Variables
      it "mongodb replica set connection" do
        FileUtils.mkpath "tmp/config"
        File.write("tmp/config/vanity.yml", <<~YML)
          mongodb:
            adapter: mongodb
            hosts:
              - localhost
            port: 27017
            database: vanity_test
        YML

        assert_equal "mongodb://localhost:27017/vanity_test", load_rails("", <<~RB, "mongodb")
          $stdout << Vanity.playground.connection
        RB

        assert_equal "Mongo::ReplSetConnection", load_rails("", <<~RB, "mongodb")
          $stdout << Vanity.playground.connection.mongo.class
        RB
      ensure
        File.unlink "tmp/config/vanity.yml"
      end
    end
  end

  it "connection from yaml missing" do
    FileUtils.mkpath "tmp/config"
    File.write("tmp/config/vanity.yml", <<~YML)
      production:
        adapter: redis
    YML

    assert_equal "No configuration for development", load_rails("\nbegin\n", <<~RB, "development")
      rescue => e
        $stdout << e.message
      end
    RB
  ensure
    File.unlink "tmp/config/vanity.yml"
  end

  it "collection from vanity yaml" do
    FileUtils.mkpath "tmp/config"
    File.write("tmp/config/vanity.yml", <<~YML)
      production:
        collecting: false
        adapter: mock
    YML
    assert_equal "false", load_rails("", <<~RB)
      $stdout << Vanity.playground.collecting?
    RB
  ensure
    File.unlink "tmp/config/vanity.yml"
  end

  it "collection true in production by default" do
    assert_equal "true", load_rails("", <<~RB)
      $stdout << Vanity.playground.collecting?
    RB
  end

  it "collection false in production when configured" do
    assert_equal "false", load_rails("\nVanity.playground.collecting = false\n", <<~RB)
      $stdout << Vanity.playground.collecting?
    RB
  end

  it "collection true in development by default" do
    assert_equal "true", load_rails("", <<~RB, "development")
      $stdout << Vanity.playground.collecting?
    RB
  end

  it "collection true in development when configured" do
    assert_equal "true", load_rails("\nVanity.playground.collecting = true\n", <<~RB, "development")
      $stdout << Vanity.playground.collecting?
    RB
  end

  it "playground loads experiments if connected" do
    assert_equal "{}", load_rails("", <<~RB)
      $stdout << Vanity.playground.experiments.inspect
    RB
  end

  it "playground does not instantiate connection if disabled" do
    ENV['VANITY_DISABLED'] = '1'
    assert_equal "false", load_rails("", <<~RB)
      Vanity.playground.experiments.inspect
      $stdout << !!Vanity.playground.connected?
    RB
  ensure
    ENV['VANITY_DISABLED'] = nil
  end

  def load_rails(before_initialize, after_initialize, env = "production")
    tmp = Tempfile.open("test.rb")
    begin
      code_setup = <<~RB
        $:.delete_if { |path| path[/gems\\/vanity-\\d/] }
        $:.unshift File.expand_path("../lib")
        RAILS_ROOT = File.expand_path(".")
      RB
      code = code_setup
      code += load_rails_3_or_4(env)
      code += %{\nrequire "vanity"\n}
      code += before_initialize
      code += initialize_rails_3_or_4
      code += after_initialize
      tmp.write code
      tmp.flush
      Dir.chdir "tmp" do
        open("| ruby #{tmp.path}").read # rubocop:todo Security/Open
      end
    ensure
      tmp.close!
    end
  end

  def load_rails_3_or_4(env)
    <<~RB
      ENV['BUNDLE_GEMFILE'] ||= "#{ENV['BUNDLE_GEMFILE']}"
      require 'bundler/setup' if File.exists?(ENV['BUNDLE_GEMFILE'])
      ENV['RAILS_ENV'] = ENV['RACK_ENV'] = "#{env}"
      require "active_model/railtie"
      require "action_controller/railtie"

      Bundler.require(:default)

      module Foo
        class Application < Rails::Application
          config.active_support.deprecation = :notify
          config.log_level = :fatal
          config.eager_load = #{env == 'production'} if Rails::Application.respond_to?(:eager_load!)
          ActiveSupport::Deprecation.silenced = true if ActiveSupport::Deprecation.respond_to?(:silenced) && ENV['CI']
        end
      end
    RB
  end

  def initialize_rails_3_or_4
    <<~RB
      Foo::Application.initialize!
    RB
  end
end
