namespace :mensa do
  namespace :tailwindcss do
    desc "Configure your Tailwind CSS"
    task :config do
      Rails::Generators.invoke("mensa:tailwind_config", ["--force"])
    end
  end

  namespace :exports do
    desc "Run recurring exports that are due"
    task recurring: :environment do
      Mensa::RecurringExportsJob.perform_now
    end
  end
end

if Rake::Task.task_defined?("tailwindcss:build")
  Rake::Task["tailwindcss:build"].enhance(["mensa:tailwindcss:config"])
  Rake::Task["tailwindcss:watch"].enhance(["mensa:tailwindcss:config"])
end
