require "rake/testtask"

spec = Gem::Specification.load(File.expand_path("vanity.gemspec", File.dirname(__FILE__)))

desc "Push new release to gemcutter and git tag"
task :push do
  sh "git push"
  puts "Tagging version #{spec.version} .."
  sh "git tag #{spec.version}"
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
desc "Run all tests (also default task)"
Rake::TestTask.new do |task|
  task.test_files = FileList['test/*_test.rb']
  task.verbose = true
  #task.warning = true
end

task(:clobber) { rm_rf "tmp" }

begin
  require "yard"
  YARD::Rake::YardocTask.new(:yardoc) do |task|
    task.files  = ["lib/**/*.rb"]
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
  Vanity.playground.load_path = "test/experiments"
  Vanity.playground.experiments.each(&:destroy)

  # Control	182	35	19.23%	N/A
  182.times { |i| experiment(:null_abc).send(:count_participant, i, nil) }
  35.times  { |i| experiment(:null_abc).send(:count_conversion, i, nil) }
  # Treatment A	180	45	25.00%	1.33
  180.times { |i| experiment(:null_abc).send(:count_participant, i, :red) }
  45.times  { |i| experiment(:null_abc).send(:count_conversion, i, :red) }
  # Treatment B	189	28	14.81%	-1.13
  189.times { |i| experiment(:null_abc).send(:count_participant, i, :green) }
  28.times  { |i| experiment(:null_abc).send(:count_conversion, i, :green) }
  # Treatment C	188	61	32.45%	2.94
  188.times { |i| experiment(:null_abc).send(:count_participant, i, :blue) }
  61.times  { |i| experiment(:null_abc).send(:count_conversion, i, :blue) }

  80.times { |i| experiment(:age_and_zipcode).send(:count_participant, i, false) }
  35.times  { |i| experiment(:age_and_zipcode).send(:count_conversion, i, false) }
  84.times { |i| experiment(:age_and_zipcode).send(:count_participant, i, true) }
  32.times  { |i| experiment(:age_and_zipcode).send(:count_conversion, i, true) }

  Vanity::Commands.report
end
