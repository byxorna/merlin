# encoding: utf-8

Gem::Specification.new do |s|
  s.name          = 'merlin'
  s.version       = %x{git describe HEAD}
  s.authors       = ['Gabe Conradi']
  s.email         = ['gabe@tumblr.com']
  s.homepage      = 'http://github.com/byxorna/merlin'
  s.summary       = %q{}
  s.description   = %q{}
  s.license       = 'Apache License 2.0'

  s.files         = Dir['lib/**/*.rb', 'bin/*', 'README.md']
  s.test_files    = Dir['spec/**/*.rb']
  s.require_paths = %w(lib)
  s.bindir        = 'bin'

  s.add_dependency "etcd", "~> 0.2.4"
  s.add_dependency "erubis", "~> 2.7.0"
  s.add_dependency "listen", "~> 2.0"
  s.add_dependency "colorize"
  s.add_dependency "eventmachine", "~> 1.0.3"

  s.add_development_dependency "rspec", "~> 3.1.0"
  s.add_development_dependency "rake"

  s.platform = Gem::Platform::RUBY
  s.required_ruby_version = '>= 1.9.3'
end
