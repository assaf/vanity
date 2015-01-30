require "test_helper"
require "vanity/commands/report"

describe Vanity::Commands do
  before do
    metric "Coolness"
  end

  describe ".report" do
    describe "given file" do
      let(:file) { "tmp/config/redis.yml" }

      it "writes to that file" do
        new_ab_test :foobar do
          alternatives "foo", "bar"
          identify { "me" }
          metrics :coolness
        end
        experiment(:foobar).choose

        FileUtils.mkpath "tmp/config"
        Vanity::Commands.report(file)
      end

      after do
        File.unlink(File.open(file, "w"))
      end
    end
  end
end
