require_relative "lib/mensa/version"

Gem::Specification.new do |spec|
  spec.name = "mensa"
  spec.version = Mensa::VERSION
  spec.authors = ["Tom de Grunt"]
  spec.email = ["tom@degrunt.nl"]
  spec.homepage = "https://github.com/entdec/mensa"
  spec.summary = "Fast and awesome tables"
  spec.description = "Fast and awesome tables, with pagination, sorting, filtering and custom views."
  spec.license = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the "allowed_push_host"
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  # spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

  spec.post_install_message = <<~MESSAGE
    Mensa requires additional setup. Please run the following
    command to install the necessary files:

    bin/rails mensa:install:migrations
  MESSAGE

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/entdec/mensa"
  spec.metadata["changelog_uri"] = "https://github.com/entdec/mensa/CHANGELOG"

  spec.files = Dir.chdir(File.expand_path("..", __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end

  spec.add_dependency "caxlsx_rails", "~> 0"
  spec.add_dependency "rails", ">= 7.1"
  spec.add_dependency "pagy", ">=43"
  spec.add_dependency "textacular", ">=5"
  spec.add_dependency "view_component", "~> 3.11"

  spec.add_dependency "slim"
  spec.add_dependency "tailwindcss-rails", "~> 3.3"
  spec.add_dependency "importmap-rails"
  spec.add_dependency "turbo-rails"
  spec.add_dependency "stimulus-rails"

  spec.add_development_dependency "sqlite3", "~> 2.8"
end
