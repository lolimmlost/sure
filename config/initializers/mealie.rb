Rails.application.configure do
  config.x.mealie ||= ActiveSupport::OrderedOptions.new
  config.x.mealie.base_url = ENV["MEALIE_BASE_URL"].presence
  config.x.mealie.api_token = ENV["MEALIE_API_TOKEN"].presence # pipelock:ignore
  config.x.mealie.timeout = ENV.fetch("MEALIE_TIMEOUT", "30").to_i
  config.x.mealie.page_size = ENV.fetch("MEALIE_PAGE_SIZE", "50").to_i
  config.x.mealie.group_slug = ENV.fetch("MEALIE_GROUP_SLUG", "home")
end
