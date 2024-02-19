source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }
git_source(:entdec) { |repo_name| "git@github.com:entdec/#{repo_name}.git" }

# Specify your gem's dependencies in mensa.gemspec.
gemspec

gem "puma"

gem 'standard', group: 'development', require: false
gem "sqlite3"

gem "sprockets-rails"

gem "satis", "~> 1", entdec: "satis", branch: "main"
gem "pry"

# Start debugger with binding.b [https://github.com/ruby/debug]
# gem "debug", ">= 1.0.0"

gem "cssbundling-rails", "~> 1.4"

gem "jsbundling-rails", "~> 1.3"

gem "slim", "~> 5.2"
