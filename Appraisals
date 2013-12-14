appraise "rails3" do
  gem "rails", "3.0.11"
  gem "fastthread", :git => "git://github.com/zoltankiss/fastthread.git", :platforms => :mri_20
  gem "passenger", "~>3.0"
  gem "mongoid", "~>2", :require => false
end

appraise "rails31" do
  gem "rails", "3.1.3"
  gem "fastthread", :git => "git://github.com/zoltankiss/fastthread.git", :platforms => :mri_20
  gem "passenger", "~>3.0"
  # Mongoid 3 is only supported on Ruby >= 1.9
  gem "mongoid", "~>3", :require => false, :platforms => :mri_19
end

appraise "rails32" do
  gem "rails", "3.2.1"
  gem "fastthread", :git => "git://github.com/zoltankiss/fastthread.git", :platforms => :mri_20
  gem "passenger", "~>3.0"
  # Mongoid 3 is only supported on Ruby >= 1.9
  gem "mongoid", "~>3", :require => false, :platforms => :mri_19
end

appraise "rails4" do
  gem "rails", "4.0.0"
  gem "fastthread", :git => "git://github.com/zoltankiss/fastthread.git", :platforms => :mri_20
  gem "passenger", "~>3.0"
  # Mongoid is not rails4 compatible: https://github.com/mongoid/mongoid/issues/3128
  # gem "bson", "~>2.0.0.rc2"
  # gem "mongoid", "~>4.0.0.alpha1", :require => false
end