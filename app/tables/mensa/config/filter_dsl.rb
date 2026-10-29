module Mensa::Config
  class FilterDsl
    include DslLogic

    option :operator, default: :is      # Operator for filtering
    option :value                       # Value for filtering

    option :collection                  # Collection shown in filtering
    option :scope                       # Scope for filtering
    option :multiple, default: false    # Multiple values allowed
    option :as
    option :operators, default: []      # Supported operators
    option :having, default: false      # Needs having when filtering
  end
end
