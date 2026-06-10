module Mensa::Config
  class FilterDsl
    include DslLogic

    option :operator, default: :is
    option :value
    option :collection
    option :scope
    option :multiple, default: false
    option :as
    option :operators
  end
end
