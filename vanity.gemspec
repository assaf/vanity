Gem::Specification.new do |spec|
  spec.name           = "vanity"
  spec.version        = "0.0.1"
  spec.author         = "Assaf Arkin"
  spec.email          = "assaf@labnotes.org"
  spec.homepage       = "http://github.com/assaf/vanity"
  spec.summary        = "Experience Driven Development framework for Rails"
  spec.description    = ""

  spec.files          = Dir["{bin,lib,example}/**/*", "CHANGELOG", "README.rdoc", "vanity.gemspec"]
  spec.executable     = "vanity"

  spec.has_rdoc         = true
  spec.extra_rdoc_files = 'README.rdoc', 'CHANGELOG'
  spec.rdoc_options     = '--title', 'Vanity', '--main', 'README.rdoc',
                          '--webcvs', 'http://github.com/assaf/vanity'
end

