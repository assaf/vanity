require "test_helper"

describe Vanity::Templates do
  describe "template" do
    it "resolves templates from the gem by default" do
      ::Rails.stubs(:root).returns('/var/www/test-app')
      File.stubs(:exists?).with('/var/www/test-app/app/views/vanity').returns(false)
      expected = File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib', 'vanity', 'templates', 'foo.html'))
      assert_equal expected, Vanity.template('foo.html')
    end

    it "resolves templates from the Rails view directory if it exists" do
      Vanity::Templates.instance_variable_set("@template_directory", nil)
      ::Rails.stubs(:root).returns('/var/www/test-app')
      File.stubs(:exists?).with('/var/www/test-app/app/views/vanity').returns(true)
      assert_equal '/var/www/test-app/app/views/vanity/foo.html', Vanity.template('foo.html')
    end
  end
end
