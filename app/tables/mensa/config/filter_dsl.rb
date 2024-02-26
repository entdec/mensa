module Mensa::Config
  class FilterDsl
    include DslLogic

    option :collection
    option :scope
  end
end
