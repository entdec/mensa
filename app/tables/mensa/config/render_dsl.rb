module Mensa::Config
  class RenderDsl
    include DslLogic

    option :html
    option :csv
  end
end
