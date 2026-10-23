require "test_helper"

# System tests run headless everywhere — no display is required, on a server or
# on a developer laptop.
#
#  * Chrome's own sandbox needs unprivileged user namespaces, which Ubuntu 23.10+
#    and modern Fedora restrict — Chrome then aborts with "No usable sandbox!"
#    (exit 134) before the first test. On Linux we therefore pass --no-sandbox,
#    plus --disable-dev-shm-usage for hosts with a small /dev/shm. These are
#    inert where the restriction doesn't apply. Opt out with CHROME_NO_SANDBOX=0.
#  * This server has no system Chrome: it uses the Playwright-bundled binary and
#    a version-matched chromedriver. Both are detected from the local filesystem,
#    so on a normal machine with desktop Chrome nothing below overrides anything.
class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  SERVER_CHROME = "/home/kirt/.cache/ms-playwright/chromium-1228/chrome-linux64/chrome".freeze
  LINUX = RUBY_PLATFORM.include?("linux")
  NO_SANDBOX = LINUX && ENV["CHROME_NO_SANDBOX"].to_s != "0"

  # nil on a laptop (no such binary) -> server-specific overrides are skipped.
  CHROME_BINARY = begin
    env = ENV["CHROME_BINARY"].to_s
    env.empty? ? (SERVER_CHROME if File.exist?(SERVER_CHROME)) : env
  end

  if CHROME_BINARY
    # chromedriver must match Chrome's MAJOR version and Selenium Manager's cache
    # can hold a different one, so pin an explicit driver when one is available.
    DRIVER = ENV.fetch("CHROMEDRIVER_PATH", File.expand_path("~/.local/bin/chromedriver"))
    Selenium::WebDriver::Chrome::Service.driver_path = DRIVER if File.exist?(DRIVER)
  end

  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ] do |options|
    options.binary = CHROME_BINARY if CHROME_BINARY

    if NO_SANDBOX
      options.add_argument("--no-sandbox")
      options.add_argument("--disable-dev-shm-usage")
      options.add_argument("--disable-gpu")
    end
  end
end
