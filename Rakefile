require "rake/rdoctask"

spec = Gem::Specification.load(File.expand_path("vanity.gemspec", File.dirname(__FILE__)))

task :push do
  version = spec.version.to_s.freeze
  sh "git push"
  puts "Tagging version #{version} .."
  sh "git tag #{version}"
  sh "git push --tag"
  puts "Building and pushing gem .."
  sh "gem build vanity.gemspec"
  sh "gem push vanity-#{version}.gem"
end

task :default=>:test
task :test do
  FileList["test/**_test.rb"].each do |file|
    require file
  end
end

Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_files.include "README.rdoc", "lib/**/*.rb"
  rdoc.options = spec.rdoc_options
  rdoc.title = "Vanity #{spec.version}"
end
