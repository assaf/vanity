require "test/test_helper"


context "Remote metrics" do
  setup do
    FileUtils.mkpath "tmp/config"
    File.open "tmp/config/vanity.yml", "w" do |f|
      f.write <<-RUBY
        metrics:
          sandbox: http://api.vanitydash.com/metrics/sandbox
      RUBY
    end
    Dir.chdir "tmp" do
      Vanity.playground.load!
    end
  end

  test "load from configuration file" do
    assert Vanity.playground.metrics[:sandbox]
  end

  test "create remote metric from configuration file" do
    stub_request :post, /vanitydash/
    metric(:sandbox).track!
    assert_requested :post, /api\.vanitydash\.com/
  end
end


context "Remote send" do
  setup do
    @metric = Vanity::Metric.new(Vanity.playground, :sandbox)
    @metric.remote "http://api.vanitydash.com/metrics/sandbox"
    Vanity.playground.metrics[:sandbox] = @metric
    stub_request :post, /vanitydash/
  end

  test "remote send in sequence" do
    Vanity.playground.track! :sandbox
    Vanity.playground.track! :sandbox
    assert_requested(:post, "http://api.vanitydash.com/metrics/sandbox", :times=>2)
  end

  test "remote sends url-encoded data" do
    Vanity.playground.track! :sandbox, 12
    assert_requested(:post, /api/) { |request| request.headers["Content-Type"] == "application/x-www-form-urlencoded" }
  end

  test "remote sends metric identifier" do
    Vanity.playground.track! :sandbox, 12
    assert_requested(:post, /api/) { |request| Rack::Utils.parse_query(request.body)["metric"] == "sandbox" }
  end

  test "remote sends RFC 2616 compliant time stamp" do
    Vanity.playground.track! :sandbox, 12
    assert_requested(:post, /api/) { |request| Time.httpdate(Rack::Utils.parse_query(request.body)["timestamp"]) }
  end

  test "remote sends array of values" do
    Vanity.playground.track! :sandbox, [1,2,3]
    assert_requested(:post, /api/) { |request| Rack::Utils.parse_query(request.body)["values[]"] == %w{1 2 3} }
  end

  test "remote sends default of 1" do
    Vanity.playground.track! :sandbox
    assert_requested(:post, /api/) { |request| Rack::Utils.parse_query(request.body)["values[]"] == "1" }
  end

  test "remote sends current identity" do
    Vanity.context = Object.new
    class << Vanity.context
      def vanity_identity
        "xkcd"
      end
    end
    Vanity.playground.track! :sandbox, 12
    assert_requested(:post, /api/) { |request| Rack::Utils.parse_query(request.body)["identity"] == "xkcd" }
  end

  test "remote sends with additional query parameters" do
    @metric.remote "http://api.vanitydash.com/metrics/sandbox?ask=receive"
    Vanity.playground.track! :sandbox, 12
    assert_requested(:post, /api/) { |request| Rack::Utils.parse_query(request.body)["ask"] == "receive" }
  end

  test "remote send handles standard error" do
    stub_request(:post, /api/).to_raise(StandardError)
    Vanity.playground.track! :sandbox
    stub_request(:post, /api/)
    Vanity.playground.track! :sandbox
    assert_requested(:post, /api/, :times=>2)
  end

  test "remote send handles timeout error" do
    stub_request(:post, /api/).to_timeout
    Vanity.playground.track! :sandbox
    stub_request(:post, /api/)
    Vanity.playground.track! :sandbox
    assert_requested(:post, /api/, :times=>2)
  end

  test "remote does not send when metrics disabled" do
    not_collecting!
    Vanity.playground.track! :sandbox
    Vanity.playground.track! :sandbox
    assert_requested(:post, /api/, :times=>0)
  end
end
