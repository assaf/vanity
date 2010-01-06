Gem::Specification.new do |spec|
  spec.name           = "vanity"
  spec.version        = "1.3.0"
  spec.author         = "Assaf Arkin"
  spec.email          = "assaf@labnotes.org"
  spec.homepage       = "http://vanity.labnotes.org"
  spec.summary        = "Experience Driven Development framework for Rails"
  spec.description    = "Mirror, mirror on the wall ..."
  spec.post_install_message = "To get started run vanity --help"

  spec.files          = Dir["{bin,lib,vendor,test}/**/*", "CHANGELOG", "MIT-LICENSE", "README.rdoc", "vanity.gemspec"]
  spec.executable     = "vanity"

  spec.has_rdoc         = true
  spec.extra_rdoc_files = "README.rdoc", "CHANGELOG"
  spec.rdoc_options     = "--title", "Vanity #{spec.version}", "--main", "README.rdoc",
                          "--webcvs", "http://github.com/assaf/#{spec.name}"
end
