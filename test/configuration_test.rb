require "test_helper"

describe Vanity::Configuration do
  let(:config) { Vanity::Configuration.new }

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
        File.open("./config/vanity.yml", "w") do |f|
          f.write VanityTestHelpers::VANITY_CONFIGS["vanity.yml.mock"]
        end

        mock_connection_hash = { adapter: "mock" }
        assert_equal mock_connection_hash, config.connection_params
      end
    end

    it "accepts a file name" do
      FileUtils.mkpath "./config"
      File.open("./config/vanity.yml", "w") do |f|
        f.write VanityTestHelpers::VANITY_CONFIGS["vanity.yml.mock"]
      end

      mock_connection_hash = { adapter: "mock" }
      assert_equal mock_connection_hash, config.connection_params("vanity.yml")
    end

    it "returns connection strings" do
      FileUtils.mkpath "./config"
      File.open("./config/redis.yml", "w") do |f|
        f.write VanityTestHelpers::VANITY_CONFIGS["redis.yml.url"]
      end

      mock_connection_string = "localhost:6379/15"
      assert_equal mock_connection_string, config.connection_params("redis.yml")
    end

    it "returns nil if the file doesn't exist" do
      FileUtils.mkpath "./config"
      assert_nil config.connection_params
    end

    it "raises an error if the environment isn't configured" do
      FileUtils.mkpath "./config"
      File.open("./config/vanity.yml", "w") do |f|
        f.write VanityTestHelpers::VANITY_CONFIGS["vanity.yml.mock"]
      end

      config.environment = "staging"
      assert_raises(Vanity::Configuration::MissingEnvironment) {
        config.connection_params
      }
    end

    it "symbolizes hash keys" do
      FileUtils.mkpath "./config"
      File.open("./config/vanity.yml", "w") do |f|
        f.write VanityTestHelpers::VANITY_CONFIGS["vanity.yml.activerecord"]
      end

      ar_connection_values = [:adapter, :active_record_adapter]
      assert_equal ar_connection_values, config.connection_params.keys
    end
  end

  describe "setup_locales" do
    it "adds vanity locales to the gem"
  end
end