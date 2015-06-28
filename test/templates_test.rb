require "test_helper"

describe Vanity::Templates do
  before do
    not_collecting!
  end

  describe "template" do
    it "resolves templates from the configured path" do
      custom_view_path = File.expand_path(File.join(Rails.root, 'app', 'views', 'vanity'))
      gem_view_path = File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib', 'vanity', 'templates'))
      expected = File.join(gem_view_path, 'foo.html')

      assert_equal expected, Vanity::Templates.new.path('foo.html')
    end

    it "resolves templates from a Rails view directory when configured" do
      begin
        custom_view_path = File.expand_path(File.join(Rails.root, 'app', 'views', 'vanity'))
        Vanity.configuration.templates_path = custom_view_path

        expected = File.expand_path(File.join(custom_view_path, 'foo.html'))

        FileUtils.mkpath(custom_view_path)
        File.open(expected, "w")

        assert_equal expected, Vanity::Templates.new.path('foo.html')
      ensure
        FileUtils.rm_rf(custom_view_path)
      end
    end

    it "ignores an empty view directory" do
      begin
        custom_view_path = File.expand_path(File.join(Rails.root, 'app', 'views', 'vanity'))
        FileUtils.mkpath(custom_view_path)

        gem_view_path = File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib', 'vanity', 'templates'))
        expected = File.join(gem_view_path, 'foo.html')

        assert_equal expected, Vanity::Templates.new.path('foo.html')
      ensure
        FileUtils.rm_rf(custom_view_path)
      end
    end
  end
end
