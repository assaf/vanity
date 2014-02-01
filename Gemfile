source 'https://rubygems.org'
gemspec

# Frameworks
gem "rack"
gem "rails", "~>2.3.8"

# Servers
gem "passenger", "~>2.0"

# Persistence
gem "redis", ">= 2.1"
gem "redis-namespace", ">= 1.1.0"
gem "bson_ext"
gem "mongo"
gem "mongoid", :require => false
gem "mysql"
gem "sqlite3"
# gem "pg"

# Math libraries
gem "backports", :platforms => :mri_18
gem "integration"
gem "rubystats"

# APIs
gem "garb"

# Compatibility
gem "SystemTimer", "1.2.3", :platforms => :mri_18

# Testing
gem "mocha", :require=>false
gem "shoulda", :require=>false # Requires test/unit
gem "timecop", :require=>false
gem "webmock", :require=>false

group :development do
  gem "appraisal", ">= 1.0.0.beta2" # For setting up test Gemfiles

  gem "jekyll"
  gem "rake"
  gem "RedCloth"
  gem "yard"
end
