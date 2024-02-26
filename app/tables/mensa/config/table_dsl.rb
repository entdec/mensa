# class UsersTable < Mensa::Base
#   definition do
#     model User
#
#     render do # default Standard components
#       html # Mensa::TableComponent::Default
#       json # Mensa::JsonRenderer::Default
#       xlsx # Mensa::XlsxRenderer::Default
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

    option :model, default: -> { self.class.name.demodulize.to_s.classify.constantize rescue raise "No model found for #{self.class.name}" }
    option :column, dsl_hash: Mensa::Config::ColumnDsl
    option :link

    # Default sort order {column: direction, column: direction}
    option :order, default: {}

    # Order of columns in the table
    option :column_order

    # Actions
    option :action, dsl_hash: Mensa::Config::ActionDsl

    dsl_option :render, Mensa::Config::RenderDsl

    option :supports_views, default: false
    option :show_header, default: true
    option :view_columns_sorting, default: true
    option :view_condensed, default: false
    option :view_condensed_toggle, default: true
  end
end
