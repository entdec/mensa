# frozen_string_literal: true

module Mensa
  class ApplicationJob
    include Sidekiq::Job
  end
end
