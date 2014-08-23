require "test_helper"

describe "bin/vanity" do

  # Hack for ActiveRecord/sqlite3 threading peculiarities
  if ENV["DB"] == "active_record"
    before do
      Vanity.playground.establish_connection
    end

    after do
      Vanity.playground.disconnect!
    end
  end

  it "responds to version" do
    proc {
      IO.any_instance.expects(:puts)
      ARGV.clear
      ARGV << '--version'
      load "bin/vanity"
    }.must_raise SystemExit
  end

  it "responds to help" do
    proc {
      IO.any_instance.expects(:puts)
      ARGV.clear
      ARGV << '--help'
      load "bin/vanity"
    }.must_raise SystemExit
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
    require "vanity/commands/upgrade"
    Vanity::Commands.expects(:upgrade)
    ARGV.clear
    ARGV << 'upgrade'
    load "bin/vanity"
  end
end