require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  class << self
    def setup_browser
      headless = !ENV.fetch("HEADLESS", "1").in?(%w[n 0 no false])

      driven_by :selenium, using: (headless ? :headless_firefox : :firefox), options: {
        browser: :remote,
        url: ENV["SELENIUM_URL"]
      } do |driver|
        driver.add_preference("intl.accept_languages", "nl")
        driver.add_preference("layout.css.prefers-color-scheme.content-override", 1)
      end

      Capybara.register_driver :selenium_dark_mode do |app|
        browser_options = Selenium::WebDriver::Firefox::Options.new
        browser_options.add_preference("intl.accept_languages", "nl")
        browser_options.add_preference("layout.css.prefers-color-scheme.content-override", 0)
        browser_options.add_argument("-headless") if headless

        Capybara::Selenium::Driver.new(app, browser: :remote, url: ENV["SELENIUM_URL"], options: browser_options)
      end

      Capybara.javascript_driver = :selenium
      Capybara.default_max_wait_time = 10
      Capybara.server = :puma, {Silent: true, Threads: "0:10", queue_requests: false}
      Capybara.server_port = 3100
      Capybara.server_host = "0.0.0.0"
      Capybara.app_host = "http://app.mensa.orb.local"
      Rails.application.routes.default_url_options[:host] = Capybara.app_host
      Rails.application.routes.default_url_options[:port] = Capybara.server_port
    end
  end

  setup_browser

  # Segment keys of the table tour (SEGMENTS in
  # app/components/mensa/table/tour_controller.js).
  TOUR_SEGMENTS = %w[search columns sorting group_by views export].freeze

  # The tour starts on a table's first visit and its overlay covers the
  # elements tests click. Capybara clears localStorage after every test, so
  # mark the tour as seen before each one.
  setup do
    visit root_url
    mark_tour_seen
  end

  # Clears this origin's localStorage, preventing state from leaking between
  # tests, but keeps the tour marked as seen.
  def clear_local_storage
    execute_script("localStorage.clear()")
    mark_tour_seen
  end

  def mark_tour_seen
    execute_script(<<~JS, TOUR_SEGMENTS)
      arguments[0].forEach((key) => localStorage.setItem(`mensa:tour:seen:${key}`, "1"));
    JS
  end
end
