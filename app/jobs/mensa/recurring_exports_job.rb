module Mensa
  # Sweeps recurring exports and re-enqueues any whose next scheduled run is due.
  # This job is intended to be invoked by a daily cron entry or scheduler.
  class RecurringExportsJob < ApplicationJob
    queue_as :default

    def perform(reference_time = Time.current)
      reference_time = reference_time.in_time_zone if reference_time.respond_to?(:in_time_zone)

      Mensa::Export.repeating.find_each do |export|
        next unless export.repeat_due?(reference_time)

        Mensa::ExportJob.perform_later(export)
      end
    end
  end
end
