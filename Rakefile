require "rake/testtask"

spec = Gem::Specification.load(File.expand_path("vanity.gemspec", File.dirname(__FILE__)))

desc "Push new release to gemcutter and git tag"
task :push do
  sh "git push"
  puts "Tagging version #{spec.version} .."
  sh "git tag v#{spec.version}"
  sh "git push --tag"
  puts "Building and pushing gem .."
  sh "gem build #{spec.name}.gemspec"
  sh "gem push #{spec.name}-#{spec.version}.gem"
end

desc "Install #{spec.name} locally"
task :install do
  sh "gem build #{spec.name}.gemspec"
  sudo = "sudo" unless File.writable?( Gem::ConfigMap[:bindir])
  sh "#{sudo} gem install #{spec.name}-#{spec.version}.gem"
end


task :default=>:test
desc "Run all tests using Redis mock (also default task)"
Rake::TestTask.new do |task|
  task.test_files = FileList['test/*_test.rb']
  if Rake.application.options.trace
    #task.warning = true
    task.verbose = true
  elsif Rake.application.options.silent
    task.ruby_opts << "-W0"
  else
    task.verbose = true
  end
end

desc "Run all tests using live redis server"
task "test:redis" do
  ENV["REDIS"] = "true"
  task(:test).invoke
end

task(:clobber) { rm_rf "tmp" }


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

desc "Create documentation in docs directory (including API)"
task :docs=>[:jekyll, :yardoc]
desc "Remove temporary files and directories"
task(:clobber) { rm_rf "html" }

desc "Publish documentation to vanity.labnotes.org"
task :publish=>[:clobber, :docs] do
  sh "rsync -cr --del --progress html/ labnotes.org:/var/www/vanity/"
end


task :report do
  $LOAD_PATH.unshift "lib"
  require "vanity"
  require "timecop"
  Vanity.playground.load_path = "test/experiments"
  Vanity.playground.experiments.values.each(&:destroy)
  Vanity.playground.metrics.values.each(&:destroy!)
  Vanity.playground.reload!

  # Control	182	35	19.23%	N/A
  # Treatment A	180	45	25.00%	1.33
  # Treatment B	189	28	14.81%	-1.13
  # Treatment C	188	61	32.45%	2.94
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
