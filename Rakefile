require "rake/testtask"
require "bundler/gem_tasks"


# -- Testing stuff --

desc "Test everything"
task "test:all"=>"test:adapters"

# Ruby versions we're testing with.
RUBIES = %w{1.9.3 2.0.0}

# Use rake test:rubies to run all combination of tests (see test:adapters) using
# all the versions of Ruby specified in RUBIES. Or to test a specific version of
# Ruby, rake test:rubies[1.8.7].
#
# This task uses RVM to install all the Ruby versions it needs, and creates a
# vanity gemset in each one that includes Bundler and all the gems specified in
# Gemfile. If anything goes south you can always wipe these gemsets or uninstall
# these Rubies and start over.
desc "Test using multiple versions of Ruby"
task "test:rubies", :ruby do |t, args|
  rubies = args.ruby ? [args.ruby] : RUBIES
  rubies.each do |ruby|
    puts "** Setup #{ruby}"
    sh "env rvm_install_on_use_flag=1 rvm_gemset_create_on_use_flag=1 rvm use #{ruby}@vanity"
    sh "rvm #{ruby}@vanity rake test:setup"
    puts
    puts "** Test using #{ruby}"
    sh "rvm #{ruby}@vanity -S bundle exec rake test:adapters #{'--trace' if Rake.application.options.trace}"
  end
end

task "test:setup" do
  # Intended to be used from test:rubies, within specific RVM context.
  begin # Make sure we got Bundler installed.
    require "bundler"
  rescue LoadError
    sh "gem install bundler"
  end
  begin # Make sure we got all the dependencies
    sh "bundle exec ruby -e puts > /dev/null"
  rescue
    sh "bundle install"
  end
end

# These are all the adapters we're going to test with.
ADAPTERS = %w{redis mongodb active_record}

desc "Test using different back-ends"
task "test:adapters", :adapter do |t, args|
  begin # Make sure we have appraisal installed and available
    require "appraisal"

    adapters = args.adapter ? [args.adapter] : ADAPTERS
    adapters.each do |adapter|
      puts "** Testing #{adapter} adapter"
      sh "bundle exec appraisal rake test DB=#{adapter} #{'--trace' if Rake.application.options.trace}"
    end
  rescue LoadError
    warn "The appraisal gem must be available"
  end
end

# Run the test suit.
Rake::TestTask.new(:test) do |task|
  task.libs << "lib"
  task.libs << "test"
  task.pattern = "test/**/*_test.rb"
  task.verbose = false
end

task :default=>:test
desc "Run all tests"

task(:clobber) { rm_rf "tmp" }


# -- Documenting stuff -- #TODO make sure works under 1.9/2.0

desc "Jekyll generates the main documentation (sans API)"
task(:jekyll) { sh "jekyll", "doc", "html" }

desc "Create documentation in docs directory"
task :docs=>[:jekyll]

desc "Remove temporary files and directories"
task(:clobber) { rm_rf "html" }

desc "Publish documentation to vanity.labnotes.org via Github Pages on gh-pages git branch"
task :publish=>[:clobber, :docs] do
  # TODO
end


# -- Misc --

task :report do
  $LOAD_PATH.unshift "lib"
  require "vanity"
  require "timecop"
  Vanity.playground.load_path = "test/experiments"
  Vanity.playground.experiments.values.each(&:destroy)
  Vanity.playground.metrics.values.each(&:destroy!)
  Vanity.playground.reload!

  # Control 182 35  19.23%  N/A
  # Treatment A 180 45  25.00%  1.33
  # Treatment B 189 28  14.81%  -1.13
  # Treatment C 188 61  32.45%  2.94
  Vanity.playground.experiment(:null_abc).instance_eval do
    fake nil=>[182,35], :red=>[180,45], :green=>[189,28], :blue=>[188,61]
    @created_at = (Date.today - 40).to_time
    @completed_at = (Date.today - 35).to_time
  end

  Vanity.playground.experiment(:age_and_zipcode).instance_eval do
    fake false=>[80,35], true=>[84,32]
    @created_at = (Date.today - 30).to_time
    @completed_at = (Date.today - 15).to_time
  end

  Vanity.context = Object.new
  Vanity.context.instance_eval { def vanity_identity ; 0 ; end }
  signups = 50
  (Date.today - 90..Date.today).each do |date|
    Timecop.travel date do
      signups += rand(15) - 5
      Vanity.playground.track! :signups, signups
    end
  end

  cheers, yawns = 0, 0
  (Date.today - 80..Date.today).each do |date|
    Timecop.travel date do
      cheers = cheers - 5 + rand(20)
      Vanity.playground.track! :yawns, cheers
      yawns = yawns - 5 + rand(30)
      Vanity.playground.track! :cheers, yawns
    end
  end

  Vanity::Commands.report ENV["OUTPUT"]
end
