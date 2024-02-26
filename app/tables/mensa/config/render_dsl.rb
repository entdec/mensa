module Mensa::Config
  class RenderDsl
    include DslLogic

    option :html
    option :xlsx
  end
end
