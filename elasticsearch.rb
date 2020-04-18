require File.expand_path '../proxy.rb', __FILE__

# Document ownership base access control:
# Each document is assumed to have owner name (username attribute)
class Elasticsearch < Proxy
  configure :production, :development do
    set :uri, URI.parse("http://localhost:9200")
    set :uid_attr, "OIDC_CLAIM_preferred_username"
  end

  # remove sinatra params
  def get_params
    params.except('splat', 'captures')
  end

  # cached request body
  def get_body
    return @body if !@body.nil?
    @body = request.body.read.to_s
  end

  # extract HTTP request headers
  def get_headers
    Hash[*env.select {|k,v| k.start_with?('HTTP_') || (k == 'CONTENT_TYPE') }
      .collect {|k,v| [k.sub(/^HTTP_/, ''), v]}
      .collect {|k,v| [k.split('_').collect(&:capitalize).join('-'), v]}
      .sort
      .flatten].except('Host', 'Connection', 'Version', 'X-Forwarded-For', 'X-Forwarded-Port', 'X-Forwarded-Proto')
  end

  # extract SSO username
  def get_username
    env[settings.uid_attr]
  end

  # Error messages
  error 403 do
    'Access forbidden'
  end

  # error handler
  def error_handler(e)
    logger.error e.message
    logger.error e.backtrace
    status 500
    { error: e.message, headers: get_headers, body: get_body, params: get_params, path: request.path }.to_json
  end

  ## URI for Login (default login page is public/login.html)
  #get '/login' do
  #  begin
  #    logger.debug "Login URI (GET), request.path: #{request.path}"
  #    [200, nil, "You have successfully logged in."]
  #  rescue StandardError => e
  #    error_handler(e)
  #  end
  #end
  
  # Root
  get '/' do
    begin
      logger.debug "Root URI (GET), request.path: #{request.path}"
      response = HTTParty.get(settings.uri, query: get_params, headers: get_headers, body: get_body)
      [response.code, response.headers, response.body]
    rescue StandardError => e
      error_handler(e)
    end
  end

  # Document API
  ## authorization logic
  def authorized?(username)
    # username becomes array or a string
    return true if (username.is_a?(Array) && username.include?(get_username)) || username == get_username
    false
  end

  ## check the request/response should be filtered or not (true/false)
  def should_be_denied?(body, r_type)
    return true if body == ""
    json = JSON.parse(body)
    if r_type == "_source"
      return false if authorized?(json["username"])
    else
      return false if authorized?(json["_source"]["username"])
    end
    true
  end

  ## Index API
  ## Update requires two phase check
  put /\/([^\/]*)\/(_doc|_create)\/(\w+)/ do |index, req_type, id|
    begin
      logger.debug "Document/Index API, request.path: #{request.path}, index: #{index}, req_type: #{req_type}, id: #{id}"
      if should_be_denied?(get_body, "_source")
        return 403
      end
      response1 = HTTParty.get(settings.uri + "/#{index}/_doc/#{id}", query: get_params, headers: get_headers.except('Accept-Encoding'), body: get_body)
      if should_be_denied?(response1.body, "_doc")
        return 403
      end
      response2 = HTTParty.put(settings.uril + request.path, query: get_params, headers: get_headers, body: get_body)
      [response2.code, response2.headers, response2.body]
    rescue StandardError => e
      error_handler(e)
    end
  end

  ## Index API
  ## Create
  post /\/([^\/]*)\/(_doc|_create)\/*/ do |index, req_type|
    begin
      logger.debug "Document/Index API, request.path: #{request.path}, index: #{index}, req_type: #{req_type}"
      if should_be_denied?(get_body, "_source")
        return 403
      end
      response = HTTParty.post(settings.uri + request.path, query: get_params, headers: get_headers, body: get_body)
      [response.code, response.headers, response.body]
    rescue StandardError => e
      error_handler(e)
    end
  end

  ## Delete API
  ## Delete requires two phase check
  delete /\/([^\/]*)\/_doc\/(\w+)/ do |index, id|
    begin
      logger.debug "Document/Delete API, request.path: #{request.path}, index: #{index}, id: #{id}"

      response1 = HTTParty.get(settings.uri + "/#{index}/_doc/#{id}", query: get_params, headers: get_headers.except('Accept-Encoding'), body: get_body)
      if should_be_denied?(response1.body, "_doc")
        return 403
      end
      response2 = HTTParty.delete(settings.uri + request.path, query: get_params, headers: get_headers, body: get_body)
      [response2.code, response2.headers, response2.body]
    rescue StandardError => e
      error_handler(e)
    end
  end

  ## Get API
  get /\/([^\/]*)\/(_doc|_source)\/(\w+)/ do |index, req_type, id|
    begin
      logger.debug "Index/Get API, request.path: #{request.path}, index: #{index}, req_type: #{req_type}, id: #{id}"
      response = HTTParty.get(settings.uri + request.path, query: get_params, headers: get_headers, body: get_body)
      if should_be_denied?(response.body, req_type)
        return 403
      end
      [response.code, response.headers, response.body]
    rescue StandardError => e
      error_handler(e)
    end
  end

  ## Update API
  ## Update requires two phase check
  post /\/([^\/]*)\/_update\/(\w+)/ do |index, id|
    begin
      logger.debug "Document/Update API, request.path: #{request.path}, index: #{index}, id: #{id}"
      if should_be_denied?(get_body, "_source")
        return 403
      end
      response1 = HTTParty.get(settings.uri + "/#{index}/_doc/#{id}", query: get_params, headers: get_headers.except('Accept-Encoding'), body: get_body)
      if should_be_denied?(response1.body, "_doc")
        return 403
      end
      response2 = HTTParty.post(settings.uril + request.path, query: get_params, headers: get_headers, body: get_body)
      [response2.code, response2.headers, response2.body]
    rescue StandardError => e
      error_handler(e)
    end
  end

  # Search API
  # additional condition for filtering denied documents
  def add_condition(body)
    return {} if body == ""
    json = JSON.parse(body)
    if json["query"].has_key?("bool")
      json["query"]["bool"]["filter"] << {"terms": {"username": [get_username]}}
    else
      json = {"query": {"bool": {"must": json["query"], "filter": {"terms": {"username": [get_username]}} } } }
    end
    json
  end

  # Search API (GET)
  get /\/([^\/]*)\/*_search/ do |index|
    begin
      logger.debug "Search API (GET), request.path: #{request.path}, index: #{index}, query: #{get_body}, filtered_query: #{add_condition(get_body).to_json}"
      response = HTTParty.get(settings.uri + request.path, query: get_params, headers: get_headers, body: add_condition(get_body).to_json)
      [response.code, response.headers, response.body]
    rescue StandardError => e
      error_handler(e)
    end
  end

  # Search API (POST)
  post /\/([^\/]*)\/*_search/ do |index|
    begin
      logger.debug "Search API (POST), request.path: #{request.path}, index: #{index}, query: #{get_body}, filtered_query: #{add_condition(get_body).to_json}"
      response = HTTParty.post(settings.uri + request.path, query: get_params, headers: get_headers, body: add_condition(get_body).to_json)
      [response.code, response.headers, response.body]
    rescue StandardError => e
      error_handler(e)
    end
  end

  # Bulk API
  post '/\/([^\/]*)\/*_bulk' do |index|
    begin
      logger.debug "Bulk API, request.path: #{request.path}, index: #{index}"
      response = HTTParty.post(settings.uri + request.path, query: get_params, headers: get_headers, body: get_body)
      [response.code, response.headers, response.body]
    rescue StandardError => e
      error_handler(e)
    end
  end
end
