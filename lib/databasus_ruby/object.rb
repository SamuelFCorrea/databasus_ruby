# frozen_string_literal: true

module DatabasusRuby
  # A thin, duck-typed wrapper around a decoded JSON payload.
  #
  #   database = client.databases.get(id)
  #   database.name                 # => "primary"
  #   database.workspace_id         # => same as database.workspaceId
  #   database.postgresqlLogical.host
  #
  # Nested hashes (and arrays of hashes) are wrapped on access, so the whole
  # tree reads the same way. The Databasus API omits empty fields, so reading a
  # key that is not in the payload returns nil rather than raising.
  class Object
    def initialize(attributes = {})
      @attributes = normalize(attributes)
    end

    def to_h
      @attributes
    end
    alias to_hash to_h

    def [](key)
      fetch_attribute(key.to_s)
    end

    def key?(key)
      return false if @attributes.nil?

      @attributes.key?(key.to_s) || @attributes.key?(camelize(key.to_s))
    end
    alias has_key? key?

    def keys
      @attributes.nil? ? [] : @attributes.keys
    end

    def ==(other)
      other.is_a?(Object) && to_h == other.to_h
    end
    alias eql? ==

    def hash
      to_h.hash
    end

    def inspect
      "#<#{self.class.name} #{keys.join(", ")}>"
    end

    def method_missing(name, *args, &block)
      # Endpoint classes inherit from Object without carrying a payload; for
      # them an unknown method is a genuine mistake, not a missing field.
      return super if @attributes.nil?
      return super unless args.empty? && block.nil?

      fetch_attribute(name.to_s)
    end

    def respond_to_missing?(name, include_private = false)
      @attributes.nil? ? super : true
    end

    private

    def normalize(attributes)
      return nil if attributes.nil?
      return attributes.to_h.transform_keys(&:to_s) if attributes.respond_to?(:to_h)

      raise ArgumentError, "expected a Hash-like payload, got #{attributes.class}"
    end

    def fetch_attribute(key)
      raw = if @attributes.key?(key)
              @attributes[key]
            else
              @attributes[camelize(key)]
            end
      wrap(raw)
    end

    def wrap(value)
      case value
      when Hash then Object.new(value)
      when ::Array then value.map { |item| wrap(item) }
      else value
      end
    end

    # workspace_id -> workspaceId, so Ruby callers can stay in snake_case.
    def camelize(key)
      head, *rest = key.split("_")
      return key if rest.empty?

      head + rest.map(&:capitalize).join
    end
  end
end
