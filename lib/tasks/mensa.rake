namespace :mensa do
  # -v/--verbose sets Rake.verbose to true, it's a default object otherwise
  verbose = -> { Rake.verbose == true }

  desc "Verify a Mensa table against the database, e.g. mensa:verify[users] (context: USER_ID=, ACCOUNT_ID=, PARAMS='{...}', STRICT=1 fails on warnings, -v or VERBOSE=1 lists every check)"
  task :verify, [:table] => :environment do |_task, args|
    abort "Usage: bin/rails \"mensa:verify[table_name]\"" if args[:table].blank?

    exit(1) unless Mensa::Verifier.run(args[:table], verbose: verbose.call)
  end

  desc "Verify all Mensa tables in app/tables against the database (context: USER_ID=, ACCOUNT_ID=, PARAMS='{...}', STRICT=1 fails on warnings, -v or VERBOSE=1 lists every check)"
  task verify_all: :environment do
    exit(1) unless Mensa::Verifier.run(verbose: verbose.call)
  end
end
