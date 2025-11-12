module Mensa::Config
  class ViewDsl
    include DslLogic

    option :name
    option :description
    option :filter, dsl_hash: Mensa::Config::FilterDsl
  end
end
