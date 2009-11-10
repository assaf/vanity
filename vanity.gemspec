Gem::Specification.new do |spec|
  spec.name           = "vanity"
  spec.version        = "0.2.0"
  spec.author         = "Assaf Arkin"
  spec.email          = "assaf@labnotes.org"
  spec.homepage       = "http://github.com/assaf/vanity"
  spec.summary        = "Experience Driven Development framework for Rails"
  spec.description    = ""
  #spec.post_install_message = "To get started run vanity --help"

  spec.files          = Dir["{bin,lib,rails,test}/**/*", "CHANGELOG", "README.rdoc", "vanity.gemspec"]

  spec.has_rdoc         = true
  spec.extra_rdoc_files = "README.rdoc", "CHANGELOG"
  spec.rdoc_options     = "--title", "Vanity #{spec.version}", "--main", "README.rdoc",
                          "--webcvs", "http://github.com/assaf/#{spec.name}"

  spec.add_dependency "redis", "0.1"
end
