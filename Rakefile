version = Gem::Specification.load(File.expand_path("vanity.gemspec", File.dirname(__FILE__))).version.to_s.freeze

task :push do
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
