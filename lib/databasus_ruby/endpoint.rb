# frozen_string_literal: true

require "uri"

module DatabasusRuby
  # Shared plumbing for the per-domain endpoint classes. Each domain is a
  # single class (DatabasusRuby::Databases, DatabasusRuby::Backups, ...) that
  # inherits Object and includes this module, so it carries both the endpoint
  # methods and the payload-reading behaviour.
  #
  # The transport helpers are prefixed `http_` so domain classes are free to
  # expose the natural #get / #create / #update / #delete names.
  module Endpoint
    attr_reader :client

    def initialize(client)
      @client = client
      # Endpoint objects are callers, not payloads; leaving @attributes nil
      # makes Object#method_missing raise NoMethodError on a typo instead of
      # quietly answering nil.
      @attributes = nil
    end

    def inspect
      "#<#{self.class.name}>"
    end

    private

    def http_get(path, params = nil)
      client.request(:get, path, params: params)
    end

    def http_post(path, body = nil, params: nil)
      client.request(:post, path, body: compact(body), params: params)
    end

    def http_put(path, body = nil, params: nil)
      client.request(:put, path, body: compact(body), params: params)
    end

    def http_delete(path, params = nil)
      client.request(:delete, path, params: params)
    end

    # Wraps a single-object response. `as` names a Record subclass for the
    # domains whose payloads carry methods of their own.
    def object(response, as: Object)
      build(as, response.body.is_a?(Hash) ? response.body : {})
    end

    # Wraps a list response; `key` names the array inside an envelope payload.
    def collection(response, key:, as: Object)
      Collection.from(response.body, key: key, wrap: ->(item) { build(as, item) })
    end

    # Records need the client to reach their related endpoints; plain payload
    # objects do not.
    def build(klass, attributes)
      klass <= Record ? klass.new(client, attributes) : klass.new(attributes)
    end

    # For endpoints that answer 200/204 with no meaningful body.
    def acknowledged(_response)
      true
    end

    # Endpoints answering a single-entry map whose key is not documented in the
    # swagger schema, e.g. GET /databases/notifier/{id}/is-using.
    def single_value(response)
      body = response.body
      body.is_a?(Hash) ? body.values.first : body
    end

    # Request bodies are built from keyword arguments, and the API distinguishes
    # an absent key from a null one in a few places, so nils are dropped.
    def compact(body)
      return body unless body.is_a?(Hash)

      body.each_with_object({}) do |(key, value), acc|
        acc[key.to_s] = value unless value.nil?
      end
    end

    # Fills in the client's default workspace for create/save payloads that
    # did not name one explicitly.
    def with_default_workspace(attributes)
      return attributes if attributes.key?(:workspaceId) || attributes.key?("workspaceId")
      return attributes if client.workspace_id.nil?

      attributes.merge(workspaceId: client.workspace_id)
    end

    def escape(segment)
      URI.encode_uri_component(require_id(segment))
    end

    # Same presence check as #escape for ids that travel in a query string or
    # body, where Faraday does the encoding.
    def require_id(segment)
      raise ArgumentError, "id is required" if segment.nil? || segment.to_s.empty?

      segment.to_s
    end
  end
end
