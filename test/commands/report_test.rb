require "test_helper"
require "vanity/commands/report"

describe Vanity::Commands do
  before do
    metric "Coolness"
  end

  def with_captured_stdout
    original_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original_stdout
  end

  describe ".report" do
    describe "given file" do
      let(:file) { "tmp/config/redis.yml" }

      it "writes to that file" do
        new_ab_test :foobar do
          alternatives "foo", "bar"
          identify { "me" }
          metrics :coolness
          default "foo"
        end
        experiment(:foobar).choose

        FileUtils.mkpath "tmp/config"

        with_captured_stdout do
          Vanity::Commands.report(file)
        end
      end

      after do
        File.unlink(File.open(file, "w"))
      end
    end
  end
end
