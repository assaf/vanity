$: << (File.dirname(__FILE__) + "/lib")
require "vanity/version"

Gem::Specification.new do |spec|
  spec.name           = "vanity"
  spec.version        = Vanity::VERSION
  spec.author         = "Assaf Arkin"
  spec.email          = "assaf@labnotes.org"
  spec.homepage       = "http://vanity.labnotes.org"
  spec.license        = "MIT"
  spec.summary        = "Experience Driven Development framework for Ruby"
  spec.description    = "Mirror, mirror on the wall ..."
  spec.post_install_message = "To get started run vanity --help"

  spec.files         = `git ls-files`.split("\n")
  spec.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  spec.executables   = `git ls-files -- bin/*`.split("\n").map { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.extra_rdoc_files = "README.md", "CHANGELOG"
  spec.rdoc_options     = "--title", "Vanity #{spec.version}", "--main", "README.md",
                          "--webcvs", "http://github.com/assaf/#{spec.name}"

  spec.required_ruby_version = ">= 2.5"

  spec.add_runtime_dependency "i18n"

  spec.add_development_dependency "appraisal", "~> 2.0"
  spec.add_development_dependency "bundler", ">= 1.8.0"
  spec.add_development_dependency "fakefs"
  spec.add_development_dependency "minitest", ">= 4.2"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "timecop"
  spec.add_development_dependency "webmock"
  spec.metadata['rubygems_mfa_required'] = 'true'
end
