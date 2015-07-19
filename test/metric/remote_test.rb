require "test_helper"

describe "Remote metrics" do
  before do
    File.open "tmp/experiments/metrics/sandbox.rb", "w" do |f|
      f.write <<-RUBY
        metric "Sandbox" do
          remote "http://api.vanitydash.com/metrics/sandbox"
        end
      RUBY
    end

    Dir.chdir "tmp" do
      Vanity.playground.load!
    end
  end

  it "loads from metrics files" do
    assert Vanity.playground.metric(:sandbox)
  end

  it "creates remote metric from metric file" do
    stub_request :post, /vanitydash/
    metric(:sandbox).track!
    assert_requested :post, /api\.vanitydash\.com/
  end
end


describe "Remote send" do
  before do
    @metric = Vanity::Metric.new(Vanity.playground, :sandbox)
    @metric.remote "http://api.vanitydash.com/metrics/sandbox"
    Vanity.playground.metrics[:sandbox] = @metric
    stub_request :post, /vanitydash/
  end

  it "remote send in sequence" do
    Vanity.playground.track! :sandbox
    Vanity.playground.track! :sandbox
    assert_requested(:post, "http://api.vanitydash.com/metrics/sandbox", :times=>2)
  end

  it "remote sends url-encoded data" do
    Vanity.playground.track! :sandbox, 12
    assert_requested(:post, /api/) { |request| request.headers["Content-Type"] == "application/x-www-form-urlencoded" }
  end

  it "remote sends metric identifier" do
    Vanity.playground.track! :sandbox, 12
    assert_requested(:post, /api/) { |request| Rack::Utils.parse_query(request.body)["metric"] == "sandbox" }
  end

  it "remote sends RFC 2616 compliant time stamp" do
    Vanity.playground.track! :sandbox, 12
    assert_requested(:post, /api/) { |request| Time.httpdate(Rack::Utils.parse_query(request.body)["timestamp"]) }
  end

  it "remote sends array of values" do
    Vanity.playground.track! :sandbox, [1,2,3]
    assert_requested(:post, /api/) { |request| Rack::Utils.parse_query(request.body)["values[]"] == %w{1 2 3} }
  end

  it "remote sends default of 1" do
    Vanity.playground.track! :sandbox
    assert_requested(:post, /api/) { |request| Rack::Utils.parse_query(request.body)["values[]"] == "1" }
  end

  it "remote sends current identity" do
    Vanity.context = Object.new
    class << Vanity.context
      def vanity_identity
        "xkcd"
      end
    end
    Vanity.playground.track! :sandbox, 12
    assert_requested(:post, /api/) { |request| Rack::Utils.parse_query(request.body)["identity"] == "xkcd" }
  end

  it "remote sends with additional query parameters" do
    @metric.remote "http://api.vanitydash.com/metrics/sandbox?ask=receive"
    Vanity.playground.track! :sandbox, 12
    assert_requested(:post, /api/) { |request| Rack::Utils.parse_query(request.body)["ask"] == "receive" }
  end

  it "remote send handles standard error" do
    stub_request(:post, /api/).to_raise(StandardError)
    Vanity.playground.track! :sandbox
    stub_request(:post, /api/)
    Vanity.playground.track! :sandbox
    assert_requested(:post, /api/, :times=>2)
  end

  it "remote send handles timeout error" do
    stub_request(:post, /api/).to_timeout
    Vanity.playground.track! :sandbox
    stub_request(:post, /api/)
    Vanity.playground.track! :sandbox
    assert_requested(:post, /api/, :times=>2)
  end

  it "remote does not send when metrics disabled" do
    not_collecting!
    Vanity.playground.track! :sandbox
    Vanity.playground.track! :sandbox
    assert_requested(:post, /api/, :times=>0)
  end
end
