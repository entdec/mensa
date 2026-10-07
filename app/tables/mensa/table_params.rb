require "digest"

module Mensa
  # Helpers for the extra +params+ a table can be built with
  # (`Mensa::Table::Component.new("name", params: {...})`). They travel to
  # Mensa's endpoints as `params[...]` query parameters, the same way
  # Mensa::Base#path sends them, so normalizing through that query-string
  # round trip gives exactly the hash the controllers receive.
  module TableParams
    module_function

    # Returns the params as a string-keyed hash with string values, or {} when
    # blank. Accepts plain hashes and ActionController::Parameters.
    def normalize(params)
      params = params.to_unsafe_h if params.respond_to?(:to_unsafe_h)
      return {} if params.blank?

      Rack::Utils.parse_nested_query({params: params}.to_query)["params"] || {}
    end

    # The permitted `params` sent along with a request to a Mensa endpoint.
    def from_request(request_params)
      normalize(request_params.slice(:params).permit(params: {}).to_h[:params])
    end

    # Query string (`params[key]=value`) to append to Mensa endpoint URLs.
    def to_query(params)
      normalized = normalize(params)
      normalized.present? ? {params: normalized}.to_query : ""
    end

    # Appends the params to +path+ as `params[...]` query parameters.
    def append_to(path, params)
      query = to_query(params)
      query.present? ? "#{path}?#{query}" : path
    end

    # Short, stable digest identifying a set of params, or nil when blank.
    def digest(params)
      query = to_query(params)
      Digest::SHA256.hexdigest(query)[0, 12] if query.present?
    end
  end
end
