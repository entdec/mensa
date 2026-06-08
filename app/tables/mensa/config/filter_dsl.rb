module Mensa::Config
  class FilterDsl
    include DslLogic

    option :operator, default: :equals
    option :value
    option :collection
    option :scope
    option :multiple, default: false
    option :as
  end
end
