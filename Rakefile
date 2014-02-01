require "rake/testtask"

# -- Building stuff --

spec = Gem::Specification.load(Dir["*.gemspec"].first)

desc "Build the Gem"
task :build do
  sh "gem build #{spec.name}.gemspec"
end

desc "Install #{spec.name} locally"
task :install=>:build do
  sudo = "sudo" unless File.writable?( Gem::ConfigMap[:bindir])
  sh "#{sudo} gem install #{spec.name}-#{spec.version}.gem"
end

desc "Push new release to gemcutter and git tag"
task :push=>["build"] do
  sh "git push"
  puts "Tagging version #{spec.version} .."
  sh "git tag v#{spec.version}"
  sh "git push --tag"
  puts "Building and pushing gem .."
  sh "gem push #{spec.name}-#{spec.version}.gem"
end


# -- Testing stuff --

desc "Test everything"
task "test:all"=>"test:adapters"

# Ruby versions we're testing with.
RUBIES = %w{1.8.7 1.9.2 2.0.0}

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
ADAPTERS = %w{redis mongodb mongoid mysql}

desc "Test using different back-ends"
task "test:adapters", :adapter do |t, args|
  begin # Make sure we have appraisal installed and available
    require "appraisal"

    adapters = args.adapter ? [args.adapter] : ADAPTERS
    adapters.each do |adapter|
      puts "** Testing #{adapter} adapter"
      sh "rake appraisal test DB=#{adapter} #{'--trace' if Rake.application.options.trace}"
    end
  rescue LoadError
    warn "The appraisal gem must be available"
  end
end

# Run the test suit.

task :default=>:test
desc "Run all tests"
Rake::TestTask.new do |task|
  task.test_files = FileList['test/**/*_test.rb']
  if Rake.application.options.trace
    #task.warning = true
    task.verbose = true
  elsif Rake.application.options.silent
    task.ruby_opts << "-W0"
  else
    task.verbose = true
  end
    task.ruby_opts << "-I."
end

task(:clobber) { rm_rf "tmp" }


# -- Documenting stuff --

begin
  require "yard"
  YARD::Rake::YardocTask.new(:yardoc) do |task|
    task.files  = FileList["lib/**/*.rb"].exclude("lib/vanity/backport.rb")
    task.options = "--output", "html/api", "--title", "Vanity #{spec.version}", "--main", "README.rdoc", "--files", "CHANGELOG"
  end
rescue LoadError
end

desc "Jekyll generates the main documentation (sans API)"
task(:jekyll) { sh "jekyll", "doc", "html" }
file "html/vanity.pdf"=>:jekyll do |t|
  pages = %w{index metrics ab_testing rails email identity configuring contributing}.map{ |p| "html/#{p}.html" }
  args = %w{--disable-javascript --outline --title Vanity --header-html doc/_layouts/_header.html --print-media-type}
  args.concat %w{--margin-left 20 --margin-right 20 --margin-top 20 --margin-bottom 20 --header-spacing 5}
  args.concat pages << t.name
  sh "wkhtmltopdf", *args
end

file "html/vanity-api.zip"=>:yardoc do |t|
  Dir.chdir "html" do
    sh "zip vanity-api.zip -r api"
  end
end
desc "Create documentation in docs directory (including API)"
task :docs=>[:jekyll, :yardoc, "html/vanity-api.zip", "html/vanity.pdf"]
desc "Remove temporary files and directories"
task(:clobber) { rm_rf "html" ; rm_rf ".yardoc" }

desc "Publish documentation to vanity.labnotes.org"
task :publish=>[:clobber, :docs] do
  sh "rsync -cr --del --progress html/ labnotes.org:/var/www/vanity/"
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
