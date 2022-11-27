require_relative "lib/callstacking/rails/version"

Gem::Specification.new do |spec|
  spec.name        = "callstacking-rails"
  spec.version     = Callstacking::Rails::VERSION
  spec.authors     = ["Jim Jones"]
  spec.email       = ["jim.jones1@gmail.com"]
  spec.homepage    = "https://github.com/callstacking/callstacking-rails"
  spec.summary     = "Rolling debugger that shows the full state of each call per request."
  spec.description = "Rolling debugger that shows the full state of each call."
  spec.license     = "MIT"
  spec.bindir      = "exe"
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/callstacking/callstacking-rails"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "rails", ">= 4"
  spec.add_dependency "faraday", "~> 2.5"
  spec.add_dependency 'faraday-follow_redirects'
  spec.add_dependency 'concurrent-ruby'
end
