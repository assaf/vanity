require "test_helper"

describe Vanity do
  describe "#configuration" do
    it "returns the same configuration" do
      assert_same Vanity.configuration, Vanity.configuration
    end

    it "returns nil if if skipping bang" do
      Vanity.configuration = nil
      assert_nil Vanity.configuration(false)
    end
  end

  describe "#configure!" do
    it "returns a configuration" do
      assert_kind_of Vanity::Configuration, Vanity.configure!
    end

    it "returns a new configuration" do
      refute_same Vanity.configure!, Vanity.configure!
    end
  end

  describe "#reset!" do
    it "creates a new configuration" do
      original_configuration = Vanity.configuration
      refute_same original_configuration, Vanity.reset!
    end
  end

  describe "#configure" do
    it "configures via a block" do
      Vanity.configure do |config|
        config.collecting = false
      end

      assert !Vanity.configuration.collecting
    end
  end

  describe "#context" do
    it "returns the context" do
      Vanity.context = Object.new
      assert_same Vanity.context, Vanity.context
    end
  end

  describe "#connection" do
    it "returns the same connection" do
      assert_same Vanity.connection, Vanity.connection
    end

    it "returns nil if if skipping bang" do
      Vanity.connection = nil
      assert_nil Vanity.connection(false)
    end
  end

  describe "#connect!" do
    it "returns a connection" do
      assert_kind_of Vanity::Connection, Vanity.connect!
    end

    it "returns a new connection" do
      refute_same Vanity.connect!, Vanity.connect!
    end

    describe "deprecated settings" do
      before do
        FakeFS.activate!
      end

      after do
        FakeFS.deactivate!
        FakeFS::FileSystem.clear
      end

      it "uses legacy connection key" do
        connection_config = VanityTestHelpers::VANITY_CONFIGS["vanity.yml.redis"]

        FileUtils.mkpath "./config"
        File.open("./config/vanity.yml", "w") do |f|
          f.write(connection_config)
        end

        Vanity::Connection.expects(:new).with("redis://:p4ssw0rd@10.0.1.1:6380/15")
        Vanity.disconnect!
        Vanity.connect!
      end

      it "uses redis.yml" do
        FileUtils.mkpath "./config"
        File.open("./config/redis.yml", "w") do |f|
          f.write VanityTestHelpers::VANITY_CONFIGS["redis.yml.url"]
        end

        Vanity::Connection.expects(:new).with("localhost:6379/15")
        Vanity.disconnect!
        Vanity.connect!
      end

      it "uses legacy collecting key" do
        connection_config = VanityTestHelpers::VANITY_CONFIGS["vanity.yml.redis"]

        FileUtils.mkpath "./config"
        File.open("./config/vanity.yml", "w") do |f|
          f.write(connection_config)
        end

        Vanity.reset!
        Vanity.disconnect!
        Vanity::Connection.stubs(:new)
        Vanity.connect!

        assert_equal false, Vanity.configuration.collecting
      end
    end
  end

  describe "#disconnect!" do
    it "sets the connection to nil" do
      Vanity.disconnect!
      assert_nil Vanity.connection(false)
    end

    it "handles nil connections" do
      Vanity.connection = nil
      assert_nil Vanity.disconnect!
    end
  end

  describe "#reconnect!" do
    it "reconnects with the same configuration" do
      Vanity.disconnect!
      original_specification = Vanity.connection.specification
      Vanity.reconnect!
      assert_equal original_specification, Vanity.connection.specification
    end

    it "creates a new connection" do
      original_configuration = Vanity.connection
      refute_same original_configuration, Vanity.reconnect!
    end
  end

   describe "#playground" do
    it "returns the same playground" do
      assert_same Vanity.playground, Vanity.playground
    end

    it "returns nil if if skipping bang" do
      Vanity.playground = nil
      assert_nil Vanity.playground(false)
    end
  end

  describe "#load!" do
    it "returns a playground" do
      assert_kind_of Vanity::Playground, Vanity.load!
    end

    it "returns a new playground" do
      refute_same Vanity.load!, Vanity.load!
    end
  end

  describe "#unload!" do
    it "sets the playground to nil" do
      Vanity.unload!
      assert_nil Vanity.playground(false)
    end
  end

  describe "#reload!" do
    it "creates a new playground" do
      original_configuration = Vanity.playground
      refute_same original_configuration, Vanity.reload!
    end
  end
end