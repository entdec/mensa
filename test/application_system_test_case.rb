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
end
