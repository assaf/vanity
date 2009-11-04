Gem::Specification.new do |spec|
  spec.name           = "vanity"
  spec.version        = "0.0.1"
  spec.author         = "Assaf Arkin"
  spec.email          = "assaf@labnotes.org"
  spec.homepage       = "http://github.com/assaf/vanity"
  spec.summary        = "Experience Driven Development framework for Rails"
  spec.description    = ""
  #spec.post_install_message = "To get started run vanity --help"

  spec.files          = Dir["{bin,lib,test,example}/**/*", "CHANGELOG", "README.rdoc", "vanity.gemspec"]
  spec.executable     = "vanity"

  spec.has_rdoc         = true
  spec.extra_rdoc_files = 'README.rdoc', 'CHANGELOG'
  spec.rdoc_options     = '--title', 'Vanity', '--main', 'README.rdoc',
                          '--webcvs', 'http://github.com/assaf/vanity'

  spec.add_dependency "redis", "0.1"
end
