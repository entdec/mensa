module Mensa
  module ApplicationHelper
    def table(name, config = {}, **options)
      options[:original_view_context] = self
      render(::Mensa::Table::Component.new(name, config, **options))
    end
  end
end
