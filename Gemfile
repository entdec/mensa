source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }
git_source(:entdec) { |repo_name| "git@github.com:entdec/#{repo_name}.git" }

# Specify your gem's dependencies in mensa.gemspec.
gemspec

gem "puma"
gem "sprockets-rails"
gem "satis", "~> 2", entdec: "satis", branch: "main"
gem "pry"
gem "capybara", "~> 3.40"
gem "selenium-webdriver", "~> 4.17"
gem "slim", "~> 5.2"
