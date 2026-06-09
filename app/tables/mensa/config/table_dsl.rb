# class UsersTable < Mensa::Base
#   definition do
#     model User
#
#     render do # default Standard components
#       html # Mensa::TableComponent::Default
#       json # Mensa::JsonRenderer::Default
#       csv # Mensa::CsvRenderer::Default
#     end
#
#     column(:first_name) do
#       filter
#       # render do
#       #   html do |c|
#       #     link_to(edit_contact_path(c)) do
#       #       content_tag("i", nil, class: "fal fa-book")
#       #     end
#       #   end
#       # end
#     end
#     column :last_name do
#       filter
#     end
#     column :email
#     column :phone_number
#     column :state
#     column :city
#     column :created_at
#
#     order last_name: :asc
#     link { |user| edit_user_path(user) }
#
#     supports_views true
#     supports_filters true
#
#     action :activate do
#       link { |user| edit_user_path(user) }
#       icon "fa-check"
#     end
#     action :delete do
#       link { |user| edit_user_path(user) }
#       link_attributes "data-turbo-method" => "delete"
#       icon "fa-xmark"
#     end
#   end

module Mensa::Config
  class TableDsl
    include DslLogic

    option :model, default: -> {
      begin
        self.class.name.demodulize.to_s.classify.gsub("Table", "").singularize.constantize
      rescue
        raise "No model found for #{self.class.name}"
      end
    }
    option :scope, default: -> { model.all }
    option :column, dsl_hash: Mensa::Config::ColumnDsl
    option :link

    option :exportable, default: true
    option :export_with_password, default: false

    # Default sort order {column: direction, column: direction}
    option :order, default: {}

    # Order of columns in the table
    option :column_order

    # Actions
    option :action, dsl_hash: Mensa::Config::ActionDsl

    option :batch, dsl_hash: Mensa::Config::BatchDsl

    option :render, dsl: Mensa::Config::RenderDsl

    option :supports_views, default: false
    option :supports_custom_views, default: false
    option :supports_filters, default: true
    option :show_header, default: true
    # Whether the table allows to change column ordering
    option :view_columns_ordering, default: true

    option :view, dsl_hash: Mensa::Config::ViewDsl

    # Syntactic sugar for `column :carrier_id do internal true end`.
    def internal(name, &block)
      column(name) do
        internal true
        instance_exec(&block) if block
      end
    end
  end
end
