require "test_helper"

module Mensa
  class RecurringExportsJobTest < ActiveJob::TestCase
    setup do
      @user = User.first
    end

    test "enqueues recurring exports that are due" do
      export = Mensa::Export.create!(
        table_name: "users",
        user: @user,
        format: "plain_csv",
        scope: "all",
        status: "completed",
        repeat: "daily",
        last_repeat_run_at: 2.days.ago
      )

      assert_enqueued_with(job: Mensa::ExportJob, args: [export]) do
        Mensa::RecurringExportsJob.perform_now(Time.current)
      end
    end

    test "does not enqueue recurring exports that are not due yet" do
      Mensa::Export.create!(
        table_name: "users",
        user: @user,
        format: "plain_csv",
        scope: "all",
        status: "completed",
        repeat: "weekly",
        last_repeat_run_at: 2.days.ago
      )

      assert_no_enqueued_jobs only: Mensa::ExportJob do
        Mensa::RecurringExportsJob.perform_now(Time.current)
      end
    end
  end
end
