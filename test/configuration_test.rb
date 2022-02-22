require "test_helper"

describe Vanity::Configuration do
  let(:config) do
    config = Vanity::Configuration.new
    config.logger = $logger # rubocop:todo Style/GlobalVars
    config
  end

  it "returns default values" do
    assert_equal Vanity::Configuration.new.collecting, Vanity::Configuration::DEFAULTS[:collecting]
  end

  describe "overriding defaults" do
    it "returns overridden values" do
      config.collecting = true
      assert_equal config.collecting, true
    end
  end

  describe "connection_params" do
    before do
      FakeFS.activate!
    end

    after do
      FakeFS.deactivate!
      FakeFS::FileSystem.clear
    end

    describe "using the default config file & path" do
      it "returns the connection params" do
        FileUtils.mkpath "./config"
        File.write("./config/vanity.yml", VanityTestHelpers::VANITY_CONFIGS["vanity.yml.mock"])

        mock_connection_hash = { adapter: "mock" }
        assert_equal mock_connection_hash, config.connection_params
      end
    end

    it "accepts a file name" do
      FileUtils.mkpath "./config"
      File.write("./config/vanity.yml", VanityTestHelpers::VANITY_CONFIGS["vanity.yml.mock"])

      mock_connection_hash = { adapter: "mock" }
      assert_equal mock_connection_hash, config.connection_params("vanity.yml")
    end

    it "returns connection strings" do
      FileUtils.mkpath "./config"
      File.write("./config/redis.yml", VanityTestHelpers::VANITY_CONFIGS["redis.yml.url"])

      mock_connection_string = "localhost:6379/15"
      assert_equal mock_connection_string, config.connection_params("redis.yml")
    end

    it "pulls from the connection config key" do
      connection_config = VanityTestHelpers::VANITY_CONFIGS["vanity.yml.redis"]

      FileUtils.mkpath "./config"
      File.write("./config/vanity.yml", connection_config)

      assert_equal "redis://:p4ssw0rd@10.0.1.1:6380/15", config.connection_url
    end

    it "renders erb" do
      connection_config = VanityTestHelpers::VANITY_CONFIGS["vanity.yml.redis-erb"]
      ENV["VANITY_TEST_REDIS_URL"] = "redis://:p4ssw0rd@10.0.1.1:6380/15"

      FileUtils.mkpath "./config"
      File.write("./config/vanity.yml", connection_config)

      connection_hash = { adapter: "redis", url: "redis://:p4ssw0rd@10.0.1.1:6380/15" }
      assert_equal connection_hash, config.connection_params
    end

    it "returns nil if the file doesn't exist" do
      FileUtils.mkpath "./config"
      assert_nil config.connection_params
    end

    it "raises an error if the environment isn't configured" do
      FileUtils.mkpath "./config"
      File.write("./config/vanity.yml", VanityTestHelpers::VANITY_CONFIGS["vanity.yml.mock"])

      config.environment = "staging"
      assert_raises(Vanity::Configuration::MissingEnvironment) do
        config.connection_params
      end
    end

    it "symbolizes hash keys" do
      FileUtils.mkpath "./config"
      File.write("./config/vanity.yml", VanityTestHelpers::VANITY_CONFIGS["vanity.yml.activerecord"])

      ar_connection_values = [:adapter, :active_record_adapter]
      assert_equal ar_connection_values, config.connection_params.keys
    end
  end

  describe "setup_locales" do
    it "adds vanity locales to the I18n gem" do
      original_load_path = I18n.load_path

      config.setup_locales

      assert_includes(
        I18n.load_path,
        File.expand_path(File.join(__FILE__, '..', '..', 'lib/vanity/locales/vanity.en.yml'))
      )
    ensure
      I18n.load_path = original_load_path
    end
  end
end
