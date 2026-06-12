module Mensa
  module ApplicationHelper
    def table(name, params: {}, **options)
      component = ::Mensa::Table::Component.new(name, params: params, **options)
      component.original_view_context = self
      render(component)
    end

    def respond_to_missing?(method, include_private = false)
      if method.to_s.ends_with?("_url") || method.to_s.ends_with?("_path") && main_app.respond_to?(method)
        true
      else
        super
      end
    end

    def method_missing(method, *args, **kwargs, &block)
      main_app.send(method, *args, **kwargs, &block)
    end
  end
end
