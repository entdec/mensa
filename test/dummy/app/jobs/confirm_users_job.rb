class ConfirmUsersJob < ApplicationJob
  def perform(records)
    records.each do |record|
      puts "User: #{record.email}"
    end
  end
end
