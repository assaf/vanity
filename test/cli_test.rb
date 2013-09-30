require "test/test_helper"

class PlaygroundTest < Test::Unit::TestCase

  def test_responds_to_version
    (RUBY_VERSION == "1.8.7" ? Object : IO).any_instance.expects(:puts)
    ARGV.clear
    ARGV << '--version'
    load "bin/vanity"
  rescue SystemExit => e
    assert e.status == 0
  end

  def test_responds_to_help
    (RUBY_VERSION == "1.8.7" ? Object : IO).any_instance.expects(:puts)
    ARGV.clear
    ARGV << '--help'
    load "bin/vanity"
  rescue SystemExit => e
    assert e.status == 0
  end

  def test_responds_to_list
    require "vanity/commands/list"
    Vanity::Commands.expects(:list)
    ARGV.clear
    ARGV << 'list'
    load "bin/vanity"
  rescue SystemExit => e
    assert e.status == 0
  end

  def test_responds_to_report
    require "vanity/commands/report"
    Vanity::Commands.expects(:report)
    ARGV.clear
    ARGV << 'report'
    load "bin/vanity"
  rescue SystemExit => e
    assert e.status == 0
  end

  def test_responds_to_unknown_commands
    require "vanity/commands/upgrade"
    Vanity::Commands.expects(:upgrade)
    ARGV.clear
    ARGV << 'upgrade'
    load "bin/vanity"
  rescue SystemExit => e
    assert e.status == 0
  end

end