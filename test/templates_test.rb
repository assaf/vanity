require "test_helper"

describe Vanity::Templates do
  before do
    not_collecting!
  end

  describe "template" do
    it "resolves templates from the gem by default" do
      custom_view_path = File.expand_path(File.join(Rails.root, 'app', 'views', 'vanity'))
      gem_view_path = File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib', 'vanity', 'templates'))
      expected = File.join(gem_view_path, 'foo.html')

      assert_equal expected, Vanity::Templates.new.path('foo.html')
    end

    it "resolves templates from the Rails view directory if it exists" do
      begin
        custom_view_path = File.expand_path(File.join(Rails.root, 'app', 'views', 'vanity'))

        expected = File.expand_path(File.join(custom_view_path, 'foo.html'))

        FileUtils.mkpath(custom_view_path)
        File.open(expected, "w")

        assert_equal expected, Vanity::Templates.new.path('foo.html')
      ensure
        FileUtils.rm_rf(custom_view_path)
      end
    end
  end
end
