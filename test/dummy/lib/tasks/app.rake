namespace :tailwindcss do
  desc "Configure your Tailwind CSS"
  task :config do
    `cp app/assets/stylesheets/application.tailwind.css.sample app/assets/stylesheets/application.tailwind.css`
    `cp config/tailwind.config.js.sample config/tailwind.config.js`
  end
end
