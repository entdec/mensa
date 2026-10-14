namespace :mensa do
  desc "Verify a Mensa table against the database, e.g. mensa:verify[users] (context: USER_ID=, ACCOUNT_ID=, PARAMS='{...}')"
  task :verify, [:table] => :environment do |_task, args|
    abort "Usage: bin/rails \"mensa:verify[table_name]\"" if args[:table].blank?

    exit(1) unless Mensa::Verifier.run(args[:table])
  end

  desc "Verify all Mensa tables in app/tables against the database (context: USER_ID=, ACCOUNT_ID=, PARAMS='{...}')"
  task verify_all: :environment do
    exit(1) unless Mensa::Verifier.run
  end
end
