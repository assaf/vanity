source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

# "development" gems in gemspec are required for testing, gems in the
# development group here are for documentation
gemspec development_group: :test

# Frameworks
gem "rack"

# Persistence
gem "redis", ">= 3.2.1"
gem "redis-namespace", ">= 1.1.0"
gem "mongo", "~> 2.1"

# Math libraries
gem "integration", "<= 0.1.0"
gem "rubystats", ">= 0.2.5"

# APIs
gem "garb", "< 0.9.2", :require => false # API changes at this version

platform :ruby do
  gem "sqlite3", "~> 1.3.10"
  gem "jekyll", "~> 2.5.3"
end

platform :jruby do
  gem "activerecord-jdbc-adapter"
  gem "jdbc-sqlite3"
end

group :development do
  gem "rake"
  gem "RedCloth"
  gem "yard"
end
