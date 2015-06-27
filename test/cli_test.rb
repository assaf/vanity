require "test_helper"

describe "bin/vanity" do

  before do
    not_collecting!
  end

  it "responds to version" do
    assert_output(nil) do
      proc {
        ARGV.clear
        ARGV << '--version'
        load "bin/vanity"
      }.must_raise SystemExit
    end
  end

  it "responds to help" do
    assert_output(nil) do
      proc {
        ARGV.clear
        ARGV << '--help'
        load "bin/vanity"
      }.must_raise SystemExit
    end
  end

  it "responds to list" do
    require "vanity/commands/list"
    Vanity::Commands.expects(:list)
    ARGV.clear
    ARGV << 'list'
    load "bin/vanity"
  end

  it "responds to report" do
    require "vanity/commands/report"
    Vanity::Commands.expects(:report)
    ARGV.clear
    ARGV << 'report'
    load "bin/vanity"
  end

  it "responds to unknown commands" do
    assert_output("No such command: upgrade\n") do
      ARGV.clear
      ARGV << 'upgrade'
      load "bin/vanity"
    end
  end
end
