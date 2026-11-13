# frozen_string_literal: true

module DatabasusRuby
  # Entry point for the gem. Holds the connection and hands out one endpoint
  # object per API domain.
  #
  #   client = DatabasusRuby::Client.new(url: "https://databasus.example.com/api/v1/")
  #   client.auth.signin(email: "ops@example.com", password: "secret")
  #   client.databases.list(workspace_id: id)
  #
  # Targets the Databasus REST API introduced in 3.65 (OpenAPI, cursor
  # pagination, RFC 9457 problem responses). `api_key` is sent as
  # `Authorization: Bearer <api_key>`; Auth#signin installs the session token
  # there.
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
        # Array filters (`status=A&status=B`) are form-style with explode,
        # which the nested encoder would send as `status[]=`.
        conn.options.params_encoder = Faraday::FlatParamsEncoder
        conn.request :json
        conn.response :json, content_type: /\bjson\b/
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

    def restores
      @restores ||= Restores.new(self)
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

    # The workspace-scoped list endpoints filter by workspace; callers can
    # either pass one per call or set a default on the client.
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
        prepare(req, params: params, headers: headers)
        req.body = body unless body.nil?
      end

      raise APIError.from_response(response) unless response.success?

      response
    end

    # GETs `path` and writes the body to `io` chunk by chunk, so a multi-GB
    # backup never sits in memory. An error answer is collected instead and
    # raised as the matching APIError. Returns the number of bytes written.
    def stream(path, io:, params: nil)
      sink = StreamSink.new(io)
      response = connection.get(path) do |req|
        prepare(req, params: params)
        # Faraday streams only when on_data is a Proc (RequestOptions#stream_response?).
        req.options.on_data = sink.to_proc
      end
      return sink.written if response.success?

      raise APIError.from_response(response, body: sink.decoded_error_body)
    end

    # Routes streamed chunks: a 2xx body goes to the caller's io, anything else
    # is kept so it can be raised as an APIError.
    class StreamSink
      attr_reader :written, :error_body

      def initialize(io)
        @io = io
        @written = 0
        @error_body = +""
      end

      def to_proc
        proc { |chunk, _received, env| write(chunk, env) }
      end

      def decoded_error_body
        return nil if error_body.empty?

        JSON.parse(error_body)
      rescue JSON::ParserError
        error_body
      end

      private

      def write(chunk, env)
        return @error_body << chunk unless env.nil? || (200..299).cover?(env.status)

        @io.write(chunk)
        @written += chunk.bytesize
      end
    end
    private_constant :StreamSink

    def inspect
      "#<#{self.class.name} url=#{url.inspect} workspace_id=#{workspace_id.inspect} " \
        "api_key=#{api_key.nil? ? "nil" : "[FILTERED]"}>"
    end

    private

    def prepare(req, params: nil, headers: nil)
      req.params.update(stringify(params)) if params
      req.headers.update(request_headers(headers))
    end

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

    # Drops nils; arrays stay arrays so FlatParamsEncoder repeats the key.
    def stringify(params)
      params.each_with_object({}) do |(key, value), acc|
        next if value.nil?

        acc[key.to_s] = value.is_a?(::Array) ? value.map(&:to_s) : value
      end
    end
  end
end
