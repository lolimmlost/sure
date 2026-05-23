class Mealie::Client
  Error = Class.new(StandardError)
  NotConfiguredError = Class.new(Error)

  def initialize(base_url: Rails.configuration.x.mealie.base_url,
                 api_token: Rails.configuration.x.mealie.api_token,
                 timeout: Rails.configuration.x.mealie.timeout,
                 page_size: Rails.configuration.x.mealie.page_size)
    raise NotConfiguredError, "MEALIE_BASE_URL not set" if base_url.blank?
    raise NotConfiguredError, "MEALIE_API_TOKEN not set" if api_token.blank?

    @base_url = base_url
    @api_token = api_token
    @timeout = timeout
    @page_size = page_size
  end

  # Yields each food hash. Paginates internally.
  def each_food(&block)
    paginate("/api/foods", &block)
  end

  # Yields each recipe summary hash (no ingredients). Paginates internally.
  def each_recipe_summary(&block)
    paginate("/api/recipes", &block)
  end

  # Returns the full recipe with recipeIngredient[] populated.
  def recipe(slug)
    get("/api/recipes/#{slug}")
  end

  private
    def paginate(path)
      page = 1
      loop do
        body = get(path, page: page, perPage: @page_size)
        items = body["items"] || []
        items.each { |item| yield item }
        break if page >= (body["total_pages"] || 1)
        page += 1
      end
    end

    def get(path, params = {})
      response = connection.get(path, params)
      raise Error, "Mealie #{response.status}: #{response.body}" unless response.success?
      response.body
    end

    def connection
      @connection ||= Faraday.new(url: @base_url) do |conn|
        conn.request :json
        conn.request :retry, max: 2, interval: 0.5, backoff_factor: 2
        conn.response :json, content_type: /\bjson$/
        conn.headers["Authorization"] = "Bearer #{@api_token}"
        conn.options.timeout = @timeout
      end
    end
end
