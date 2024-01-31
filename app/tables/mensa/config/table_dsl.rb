# class UserTable
#   model User # implicit from name
#
#   default_order [[:name, :desc], [:second, :asc]] # default: no explict ordering
#
#   filter do |query| # default ?
#     where(....)
#   end
#
#   render do # default Standard components
#     html Mensa::TableComponent::Default
#     json Mensa::JsonRenderer::Default
#     xlsx Mensa::XlsxRenderer::Default
#   end
#
#   column(:name) do
#     attribute :name
#     order ->(direction) { order(:name, direction)}
#
#     filter do
#       collection -> { }
#       scope -> { where(name: ...)}
#     end
#
#     header_cell do # default Standard components
#       html(sanitize: true) ->(value) { Mensa::HeaderCellComponent::Default.render(value) }
#     end
#
#     body_cell do # default Standard components
#       html ->(value) { Mensa::BodyCellComponent::Default.render(value) }
#     end
#   end
# end

module Mensa::Config
  class TableDsl
    include DslLogic

    option :model, default: -> { self.class.name.demodulalize.to_s.classify.constantize rescue raise "No model found for #{self.class.name}" }
    option :column, dsl_hash: Mensa::Config::ColumnDsl
    option :link

    # Default sort order
    option :order, default: []

    # Order of columns in the table
    option :column_order

    option :views, default: true
  end
end
