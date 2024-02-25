require_relative "lib/mensa/version"

Gem::Specification.new do |spec|
  spec.name        = "mensa"
  spec.version     = Mensa::VERSION
  spec.authors     = ["Tom de Grunt"]
  spec.email       = ["tom@degrunt.nl"]
  spec.homepage    = "https://github.com/entdec/mensa"
  spec.summary     = "Fancy tables."
  spec.description = "Fancy tables for fancy people"
  spec.license     = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the "allowed_push_host"
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  # spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/entdec/mensa"
  spec.metadata["changelog_uri"] = "https://github.com/entdec/mensa/CHANGELOG"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency 'caxlsx_rails', '~> 0'
  spec.add_dependency "rails", ">= 7.0.4"
  spec.add_dependency 'pagy', '>=6'
  spec.add_dependency 'textacular', '>=5'
end
