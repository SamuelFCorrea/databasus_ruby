# frozen_string_literal: true

module DatabasusRuby
  # Uniform return value for every list endpoint.
  #
  # Databasus answers lists in three different shapes: a bare array
  # (GET /databases), a paginated envelope (GET /backups) and an unpaginated
  # envelope (GET /workspaces). Collection flattens all three into an
  # Enumerable that always answers #total, and answers #limit / #offset when
  # the endpoint actually paginates.
  class Collection
    include Enumerable

    attr_reader :data, :total, :limit, :offset

    # `wrap` builds one entry from its raw hash; it defaults to a plain Object
    # and endpoints pass a Record builder instead.
    def initialize(data: [], total: nil, limit: nil, offset: nil, wrap: nil)
      @data = data.map { |item| item.is_a?(Object) ? item : (wrap || Object.method(:new)).call(item) }
      @total = total || @data.size
      @limit = limit
      @offset = offset
    end

    # `key` names the array inside an envelope response and is ignored for
    # bare-array responses.
    def self.from(body, key:, wrap: nil)
      case body
      when ::Array
        new(data: body, wrap: wrap)
      when Hash
        new(data: body[key] || [], total: body["total"], limit: body["limit"], offset: body["offset"], wrap: wrap)
      when nil
        new
      else
        raise Error, "unexpected list payload: #{body.class}"
      end
    end

    def each(&block)
      return data.each unless block

      data.each(&block)
      self
    end

    def size
      data.size
    end
    alias length size

    def empty?
      data.empty?
    end

    def [](index)
      data[index]
    end

    def last
      data.last
    end

    def paginated?
      !limit.nil?
    end

    # Offset to pass to the next call, or nil when this is the last page (or
    # the endpoint does not paginate at all).
    def next_offset
      return nil unless paginated?

      following = (offset || 0) + data.size
      following < total ? following : nil
    end

    def last_page?
      next_offset.nil?
    end

    def inspect
      "#<#{self.class.name} size=#{size} total=#{total} limit=#{limit.inspect} offset=#{offset.inspect}>"
    end
  end
end
