module Mensa::Config
  class RenderDsl
    include DslLogic

    option :html, default: ->(cell) { cell.value }
  end
end
