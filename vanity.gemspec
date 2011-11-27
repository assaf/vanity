$: << File.dirname(__FILE__) + "/lib"
require "vanity/version"

Gem::Specification.new do |spec|
  spec.name           = "vanity"
  spec.version        = Vanity::VERSION
  spec.author         = "Assaf Arkin"
  spec.email          = "assaf@labnotes.org"
  spec.homepage       = "http://vanity.labnotes.org"
  spec.summary        = "Experience Driven Development framework for Ruby"
  spec.description    = "Mirror, mirror on the wall ..."
  spec.post_install_message = "To get started run vanity --help"

  spec.files         = `git ls-files`.split("\n")
  spec.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  spec.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.extra_rdoc_files = "README.rdoc", "CHANGELOG"
  spec.rdoc_options     = "--title", "Vanity #{spec.version}", "--main", "README.rdoc",
                          "--webcvs", "http://github.com/assaf/#{spec.name}"

  spec.required_ruby_version = '>= 1.8.7'
  spec.add_dependency "redis", "~>2.0"
  spec.add_dependency "redis-namespace", "~>1.0.0"
end
