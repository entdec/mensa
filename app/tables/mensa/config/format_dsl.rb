module Mensa::Config
  class FormatDsl
    include DslLogic

    option :time_zone, default: -> { Time.zone }
  end
end
