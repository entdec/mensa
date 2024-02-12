# desc "Explaining what the task does"
# task :mensa do
#   # Task goes here
# end

task :tailwind_watch do
  require 'tailwindcss-rails'
  system "#{Tailwindcss::Engine.root.join("exe/tailwindcss")} \
    -i #{Mensa::Engine.root.join("app/assets/stylesheets/mensa/application.tailwind.css")} \
    -o #{Mensa::Engine.root.join("app/assets/builds/mensa.css")} \
    -c #{Mensa::Engine.root.join("config/tailwind.config.js")} \
    --minify \
    -w"
end