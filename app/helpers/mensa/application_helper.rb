module Mensa
  module ApplicationHelper
    def table(name, params: {}, **options)
      component = ::Mensa::Table::Component.new(name, params: params, **options)
      component.original_view_context = self
      render(component)
    end

    # The app's url helpers, also inside Mensa's engine views
    def respond_to_missing?(method, include_private = false)
      main_app_url_helper?(method) || super
    end

    def method_missing(method, *args, **kwargs, &block)
      return super unless main_app_url_helper?(method)

      main_app.public_send(method, *args, **kwargs, &block)
    end

    private

    def main_app_url_helper?(method)
      method.to_s.end_with?("_url", "_path") && main_app.respond_to?(method)
    end
  end
end
