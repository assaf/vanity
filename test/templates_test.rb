require "test_helper"

describe Vanity::Templates do
  describe "template" do
    it "resolves templates from the gem by default" do
      Vanity::Templates.instance_variable_set("@template_directory", nil)
      custom_view_path = File.expand_path(File.join(Rails.root || '.', 'app', 'views', 'vanity'))
      gem_view_path = File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib', 'vanity', 'templates'))
      expected = File.join(gem_view_path, 'foo.html')

      File.stubs(:exists?).with(custom_view_path).returns(false)
      File.stubs(:exists?).with(gem_view_path).returns(true)

      assert_equal expected, Vanity.template('foo.html')
    end

    it "resolves templates from the Rails view directory if it exists" do
      Vanity::Templates.instance_variable_set("@template_directory", nil)
      custom_view_path = File.expand_path(File.join(Rails.root || '.', 'app', 'views', 'vanity'))
      File.stubs(:exists?).with(custom_view_path).returns(true)

      expected = File.expand_path(File.join(custom_view_path, 'foo.html'))
      assert_equal expected, Vanity.template('foo.html')
    end
  end
end
