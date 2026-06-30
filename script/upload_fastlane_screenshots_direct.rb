#!/usr/bin/env ruby
# frozen_string_literal: true

require "spaceship"

APP_IDENTIFIER = ENV.fetch("PEEK_APP_IDENTIFIER", "com.shifeng.peek")
SCREENSHOTS_ROOT = File.expand_path(
  ENV.fetch("PEEK_FASTLANE_SCREENSHOTS_ROOT", File.join(__dir__, "..", "fastlane", "screenshots"))
)
DISPLAY_TYPE_PATTERN = /_DESKTOP_/
DISPLAY_TYPE = "APP_DESKTOP"

def required_env(name)
  value = ENV[name].to_s
  abort("upload_fastlane_screenshots_direct failed: set #{name}") if value.empty?
  value
end

def screenshot_locales
  configured = ENV["PEEK_FASTLANE_SCREENSHOT_LOCALES"].to_s
  if configured.empty?
    Dir.children(SCREENSHOTS_ROOT).select { |entry| File.directory?(File.join(SCREENSHOTS_ROOT, entry)) }.sort
  else
    configured.split(",").map(&:strip).reject(&:empty?)
  end
end

key_path = ENV["ASC_KEY_PATH"].to_s.empty? ? ENV["APP_STORE_CONNECT_API_KEY_PATH"].to_s : ENV["ASC_KEY_PATH"].to_s
key_content = ENV["ASC_KEY_CONTENT"].to_s.empty? ? ENV["APP_STORE_CONNECT_API_KEY_CONTENT"].to_s : ENV["ASC_KEY_CONTENT"].to_s

token_options = {
  key_id: required_env("ASC_KEY_ID"),
  issuer_id: required_env("ASC_ISSUER_ID"),
  in_house: false
}

if key_content.empty?
  abort("upload_fastlane_screenshots_direct failed: set ASC_KEY_PATH or ASC_KEY_CONTENT") if key_path.empty?
  token_options[:filepath] = File.expand_path(key_path)
else
  token_options[:key] = key_content
  token_options[:is_key_content_base64] = ENV["ASC_KEY_CONTENT_BASE64"] == "1"
end

Spaceship::ConnectAPI.token = Spaceship::ConnectAPI::Token.create(**token_options)

app = Spaceship::ConnectAPI::App.find(APP_IDENTIFIER)
abort("upload_fastlane_screenshots_direct failed: app not found for #{APP_IDENTIFIER}") if app.nil?

version = app.get_edit_app_store_version(platform: Spaceship::ConnectAPI::Platform::MAC_OS)
abort("upload_fastlane_screenshots_direct failed: no editable macOS App Store version") if version.nil?

localizations = version.get_app_store_version_localizations.each_with_object({}) do |localization, map|
  map[localization.locale] = localization
end

screenshot_locales.each do |locale|
  localization = localizations[locale]
  abort("upload_fastlane_screenshots_direct failed: missing App Store localization #{locale}") if localization.nil?

  locale_dir = File.join(SCREENSHOTS_ROOT, locale)
  paths = Dir[File.join(locale_dir, "*.png")].select { |path| File.basename(path).match?(DISPLAY_TYPE_PATTERN) }.sort
  abort("upload_fastlane_screenshots_direct failed: no desktop screenshots in #{locale_dir}") if paths.empty?
  abort("upload_fastlane_screenshots_direct failed: #{locale} has more than 10 screenshots") if paths.length > 10

  screenshot_set = localization.get_app_screenshot_sets.find do |candidate|
    candidate.screenshot_display_type == DISPLAY_TYPE
  end

  if screenshot_set.nil?
    puts("creating screenshot set locale=#{locale} type=#{DISPLAY_TYPE}")
    screenshot_set = localization.create_app_screenshot_set(attributes: { screenshotDisplayType: DISPLAY_TYPE })
  else
    existing = screenshot_set.app_screenshots || []
    puts("deleting existing screenshots locale=#{locale} count=#{existing.length}")
    existing.each(&:delete!)
    screenshot_set = Spaceship::ConnectAPI::AppScreenshotSet.get(app_screenshot_set_id: screenshot_set.id)
  end

  uploaded_ids = paths.each_with_index.map do |path, index|
    puts("uploading locale=#{locale} index=#{index + 1} file=#{File.basename(path)}")
    screenshot_set.upload_screenshot(path: path, wait_for_processing: true, position: index).id
  end

  screenshot_set = Spaceship::ConnectAPI::AppScreenshotSet.get(app_screenshot_set_id: screenshot_set.id)
  screenshot_set.reorder_screenshots(app_screenshot_ids: uploaded_ids)
  puts("uploaded locale=#{locale} count=#{uploaded_ids.length}")
end
