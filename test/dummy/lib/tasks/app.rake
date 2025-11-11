namespace :tailwindcss do
  desc "Configure your Tailwind CSS"
  task :config do
    `cp test/dummy/app/assets/stylesheets/application.tailwind.css.sample test/dummy/app/assets/stylesheets/application.tailwind.css`
    `cp test/dummy/config/tailwind.config.js.sample test/dummy/config/tailwind.config.js`
  end
end
