require "rake/rdoctask"
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
desc "Run all tests"
Rake::TestTask.new do |task|
  task.test_files = FileList['test/*_test.rb']
  task.verbose = true
  #task.warning = true
end

Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_files.include "README.rdoc", "lib/**/*.rb"
  rdoc.options = spec.rdoc_options
  rdoc.options << "-f" << "darkfish"
end

task :report do
  require "lib/vanity"
  Vanity.playground.load_path = "test/experiments"

  class Context
    def session
      @session ||= {}
    end
    attr_accessor :vanity_identity
  end
  Vanity.context = Context.new
  identity = ->(id){ Vanity.context.vanity_identity = id }

  experiment(:null_abc).reset!
  # Control	182	35	19.23%	N/A
  182.times { |i| identity[i]; experiment(:null_abc).chooses(nil).choose }
  35.times  { |i| identity[i]; experiment(:null_abc).chooses(nil).conversion! }
  # Treatment A	180	45	25.00%	1.33
  180.times { |i| identity[i]; experiment(:null_abc).chooses(:red).choose }
  45.times  { |i| identity[i]; experiment(:null_abc).chooses(:red).conversion! }
  # Treatment B	189	28	14.81%	-1.13
  189.times { |i| identity[i]; experiment(:null_abc).chooses(:green).choose }
  28.times  { |i| identity[i]; experiment(:null_abc).chooses(:green).conversion! }
  # Treatment C	188	61	32.45%	2.94
  188.times { |i| identity[i]; experiment(:null_abc).chooses(:blue).choose }
  61.times  { |i| identity[i]; experiment(:null_abc).chooses(:blue).conversion! }

  experiment(:age_and_zipcode).reset!
  182.times { |i| identity[i]; experiment(:age_and_zipcode).chooses(false).choose }
  35.times  { |i| identity[i]; experiment(:age_and_zipcode).chooses(false).conversion! }
  180.times { |i| identity[i]; experiment(:age_and_zipcode).chooses(true).choose }
  45.times  { |i| identity[i]; experiment(:age_and_zipcode).chooses(true).conversion! }
  experiment(:age_and_zipcode).complete!

  Vanity::Commands.report
end
