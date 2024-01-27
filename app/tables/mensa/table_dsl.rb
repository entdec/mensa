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

module Mensa
  class TableDsl
    include SharedDsl
    attr_reader :config

    def initialize(name, &)
      @config = {
        columns: [],
        order: []
      }
      instance_eval(&) if block_given?
    end

    def column(name, &)
      config[:columns] << Mensa::ColumnDsl.new(name, &).config
    end

    option :model
    option :link
    option :order
    option :column_order
  end
end