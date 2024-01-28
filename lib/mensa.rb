require "mensa/version"
require "mensa/engine"

require 'pagy'
require 'satis'

require_relative 'mensa/configuration'

module Mensa
  extend Configurable

  class << self
    def for_name(name, params = {})
      class_for_name(name).new(params)
    end

    def class_for_name(name)
      class_name = "#{name}_table".camelcase
      unless class_name.safe_constantize
        module_class_name = name.to_s.split('_', 2).map(&:camelcase).join('::') + 'Table'
        class_name = module_class_name if module_class_name.safe_constantize
      end
      Kernel.const_get("::#{class_name}")
    rescue NameError
      raise NotImplementedError, "No '#{name}' table defined."
    end
  end
end
