# frozen_string_literal: true

module DatabasusRuby
  # Entry point for the gem. Holds the connection and hands out one endpoint
  # object per API domain.
  #
  #   client = DatabasusRuby::Client.new(
  #     api_key: ENV["DATABASUS_API_KEY"],
  #     url: "https://databasus.example.com/api/v1/"
  #   )
  #   client.databases.list(workspace_id: id)
  #
  # `api_key` is sent as `Authorization: Bearer <api_key>`. Databasus accepts
  # two kinds of bearer token there: a user JWT (from Auth#signin, used by
  # every regular endpoint) and a verification-agent token (used by the
  # /agent/* endpoints, which also need `agent_id`).
  class Client
    attr_reader :adapter, :url
    attr_accessor :api_key, :workspace_id

    def initialize(api_key: nil, url: nil, workspace_id: nil, adapter: Faraday.default_adapter)
      raise ConfigurationError, "url is required" if url.nil? || url.to_s.empty?

      @api_key = api_key
      @adapter = adapter
      @url = normalize_url(url)
      @workspace_id = workspace_id
    end

    def connection
      @connection ||= Faraday.new do |conn|
        conn.url_prefix = url
        conn.request :json
        conn.response :json, content_type: "application/json"
        conn.adapter adapter
      end
    end

    def auth
      @auth ||= Auth.new(self)
    end

    def backups
      @backups ||= Backups.new(self)
    end

    def databases
      @databases ||= Databases.new(self)
    end

    def notifiers
      @notifiers ||= Notifiers.new(self)
    end

    def storages
      @storages ||= Storages.new(self)
    end

    def users
      @users ||= Users.new(self)
    end

    def workspaces
      @workspaces ||= Workspaces.new(self)
    end

    # The workspace-scoped list endpoints all require a workspace id; callers
    # can either pass one per call or set a default on the client.
    def workspace_id!
      return workspace_id unless workspace_id.nil? || workspace_id.to_s.empty?

      raise ConfigurationError,
            "workspace_id is required: pass workspace_id: to this call or to Client.new"
    end

    # Performs the request and raises the matching APIError subclass on a
    # non-successful status. Returns the raw Faraday::Response so callers can
    # decide how to interpret the body.
    def request(method, path, params: nil, body: nil, headers: nil)
      response = connection.public_send(method, path) do |req|
        req.params.update(stringify(params)) if params
        req.body = body unless body.nil?
        req.headers.update(request_headers(headers))
      end

      raise APIError.from_response(response) unless response.success?

      response
    end

    def inspect
      "#<#{self.class.name} url=#{url.inspect} workspace_id=#{workspace_id.inspect}\
      api_key=#{api_key.nil? ? "nil" : "[FILTERED]"}>"
    end

    private

    # Databasus takes the token as a bearer credential; both a user JWT and a
    # verification-agent token go in the same header.
    def request_headers(extra)
      headers = {}
      headers["Authorization"] = "Bearer #{api_key}" unless api_key.nil? || api_key.to_s.empty?
      headers.update(extra) if extra
      headers
    end

    # Faraday resolves a path without a leading slash against url_prefix, so
    # the prefix has to keep its trailing slash or /api/v1 would be dropped.
    def normalize_url(url)
      url.to_s.end_with?("/") ? url.to_s : "#{url}/"
    end

    def stringify(params)
      params.each_with_object({}) do |(key, value), acc|
        next if value.nil?

        # The only array-valued query parameter in the API (backups status)
        # is declared as collectionFormat: csv.
        acc[key.to_s] = value.is_a?(::Array) ? value.join(",") : value
      end
    end
  end
end
