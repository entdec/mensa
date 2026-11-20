# frozen_string_literal: true

module Mensa
  # What a batch action's process gets besides the records:
  #
  #   process do |users, batch|
  #     next batch.errors.add(:reason, :blank) if batch.params[:reason].blank?
  #
  #     users.update_all(archived_reason: batch.params[:reason])
  #     batch.redirect_to users_path, notice: "#{batch.count} users archived"
  #   end
  #
  # It's also the object the dialog's form is built on, so the fields show the
  # submitted values and errors again when the dialog is shown with errors.
  class Batch
    include ActiveModel::Model

    attr_reader :table, :action, :records, :params, :user, :redirect_url, :flash

    def initialize(table:, action:, records: nil, params: nil, user: nil, count: nil)
      super()
      @table = table
      @action = action
      @records = records
      @params = params || ActionController::Parameters.new
      @user = user
      @count = count
      @flash = {}
    end

    # The number of selected records
    def count
      @count ||= records ? records.count : 0
    end

    # Where to go after the action, with an optional notice or alert. Without
    # a url it goes back to the table.
    def redirect_to(url = nil, notice: nil, alert: nil)
      @redirect_url = url
      @flash = {notice: notice, alert: alert}.compact
    end

    # The submitted values, so form fields show them again
    def respond_to_missing?(name, include_private = false)
      params.key?(name.to_s) || super
    end

    def method_missing(name, *args)
      return params[name.to_s] if args.empty? && params.key?(name.to_s)

      super
    end
  end
end
