Gem::Specification.new do |spec|
  spec.name           = "vanity"
  spec.version        = "1.4.0"
  spec.author         = "Assaf Arkin"
  spec.email          = "assaf@labnotes.org"
  spec.homepage       = "http://vanity.labnotes.org"
  spec.summary        = "Experience Driven Development framework for Ruby"
  spec.description    = "Mirror, mirror on the wall ..."
  spec.post_install_message = "To get started run vanity --help"

  spec.files          = Dir["{bin,lib,vendor,test}/**/*", "CHANGELOG", "MIT-LICENSE", "README.rdoc", "Rakefile", "Gemfile", "vanity.gemspec"]
  spec.executable     = "vanity"

  spec.has_rdoc         = true
  spec.extra_rdoc_files = "README.rdoc", "CHANGELOG"
  spec.rdoc_options     = "--title", "Vanity #{spec.version}", "--main", "README.rdoc",
                          "--webcvs", "http://github.com/assaf/#{spec.name}"

  spec.add_dependency "redis", "~>2.0"
  spec.add_dependency "redis-namespace", "~>0.7"
end
