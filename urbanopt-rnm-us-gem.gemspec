
lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'urbanopt/rnm/version'

Gem::Specification.new do |spec|
  spec.name          = 'urbanopt-RNM-us'
  spec.version       = URBANopt::RNM::VERSION
  spec.authors       = ['Katherine Fleming']
  spec.email         = ['katherine.fleming@nrel.gov']

  spec.summary       = 'Library to create input files for RNM-US'
  spec.description   = 'Library to create input files for RNM-US'
  spec.homepage      = 'https://github.com/urbanopt/urbanopt-RNM-us-gem'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib', 'example_inputs']
  spec.required_ruby_version = '~> 2.5.0'

  spec.add_development_dependency 'bundler', '~> 2.1'
  spec.add_development_dependency 'rake', '~> 12.3'
  spec.add_development_dependency 'rspec', '~> 3.7'
  spec.add_dependency 'rubocop', '~> 0.54.0'
  spec.add_dependency 'rubocop-checkstyle_formatter', '~> 0.4.0'
  spec.add_dependency 'geoutm', '~>1.0.2'
  spec.add_dependency 'faraday', '1.0.1'
  
end
