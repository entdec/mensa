module Mensa
  # An export request for a Mensa table. Each export captures the table it was
  # generated for, the view (if any), the requesting user and the request
  # configuration (filters/query/order/page) needed to rebuild the data. Once
  # processed by Mensa::ExportJob the generated CSV is stored in +asset+.
  class Export < ApplicationRecord
    STATUSES = %w[pending processing completed failed].freeze
    FORMATS = %w[csv_excel plain_csv].freeze
    SCOPES = %w[all current_page].freeze

    belongs_to :user, optional: true
    has_one_attached :asset

    validates :table_name, presence: true
    validates :status, inclusion: {in: STATUSES}

    scope :for_table, ->(table_name) { where(table_name: table_name.to_s) }
    scope :for_user, ->(user) { where(user_id: user.respond_to?(:id) ? user&.id : user) }
    scope :completed, -> { where(status: "completed") }
    scope :recent, -> { order(created_at: :desc) }

    def completed?
      status == "completed"
    end

    def failed?
      status == "failed"
    end

    def processing?
      status == "processing"
    end

    def pending?
      status == "pending"
    end

    # True once the asset is ready to be downloaded by the user.
    def downloadable?
      completed? && asset.attached?
    end

    # Number of completed (downloadable) exports for a table/user combination.
    # This is the number rendered in the export button badge.
    def self.completed_count(table_name, user)
      for_table(table_name).for_user(user).completed.count
    end

    # A stable, page-independent key identifying the exports of a table/user
    # combination, used for Turbo stream names and DOM ids so background jobs
    # can target them after completion.
    def self.token(table_name, user)
      user_key = user.respond_to?(:id) ? user&.id : user
      [table_name.to_s, user_key || "anonymous"].join("-").parameterize
    end

    def self.stream_name(table_name, user)
      "mensa-exports-#{token(table_name, user)}"
    end

    def self.badge_dom_id(table_name, user)
      "mensa-export-badge-#{token(table_name, user)}"
    end

    def self.list_dom_id(table_name, user)
      "mensa-export-list-#{token(table_name, user)}"
    end

    # Re-renders the export button badge and downloads list for everyone
    # subscribed to this table/user's export stream. Best-effort: a missing
    # Action Cable backend (or other broadcast failure) must never break the
    # caller (job completion, download cleanup, ...).
    def self.broadcast_refresh(table_name, user)
      stream = stream_name(table_name, user)

      Turbo::StreamsChannel.broadcast_replace_to(
        stream,
        target: badge_dom_id(table_name, user),
        partial: "mensa/exports/badge",
        locals: {table_name: table_name, user: user}
      )

      Turbo::StreamsChannel.broadcast_replace_to(
        stream,
        target: list_dom_id(table_name, user),
        partial: "mensa/exports/list",
        locals: {table_name: table_name, user: user, exports: for_table(table_name).for_user(user).recent}
      )
    rescue => e
      Mensa.config.logger&.warn("Mensa::Export broadcast failed: #{e.class}: #{e.message}")
    end
  end
end
