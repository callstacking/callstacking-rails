require_relative "lib/callstacking/rails/version"

Gem::Specification.new do |spec|
  spec.name        = "callstacking-rails"
  spec.version     = Callstacking::Rails::VERSION
  spec.authors     = ["Jim Jones"]
  spec.email       = ["jim.jones1@gmail.com"]
  spec.homepage    = "https://github.com/callstacking/callstacking-rails"
  spec.summary     = "Quickly visualize which methods call which, their parameters, and return values."
  spec.description = "Quickly visualize which methods call which, their parameters, and return values."
  spec.license     = "GPL-3.0-or-later"
  spec.bindir      = "exe"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/callstacking/callstacking-rails"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib,exe}/**/*", "LICENSE", "Rakefile", "README.md"]
  end
  
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }

  spec.add_dependency "rails", ">= 4"
  spec.add_dependency "faraday", '>= 1.10.3'
  spec.add_dependency 'faraday-follow_redirects'
  spec.add_dependency 'async-http-faraday'
  spec.add_development_dependency 'mocha'
  spec.add_development_dependency 'minitest-silence'
end
