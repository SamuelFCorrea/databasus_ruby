# frozen_string_literal: true

module DatabasusRuby
  # Uniform return value for every list endpoint.
  #
  # Databasus answers every list as a cursor page: `{ items: [...],
  # nextCursor: "..." }`, plus page-level extras on some endpoints (the logical
  # backups page carries `totalUsageMb`). Pass #next_cursor back as `after:` to
  # read the next page; it is nil on the last one.
  #
  #   page = client.backups.list(database_id: id, limit: 50)
  #   page.extras.total_usage_mb
  #   page.next_cursor
  class Collection
    include Enumerable

    attr_reader :data, :next_cursor, :extras

    # `wrap` builds one entry from its raw hash; it defaults to a plain Object
    # and endpoints pass a Record builder instead.
    def initialize(data: [], next_cursor: nil, extras: {}, wrap: nil)
      @data = data.map { |item| item.is_a?(Object) ? item : (wrap || Object.method(:new)).call(item) }
      @next_cursor = next_cursor
      @extras = extras.is_a?(Object) ? extras : Object.new(extras)
    end

    PAGE_KEYS = %w[items nextCursor].freeze

    def self.from(body, wrap: nil)
      case body
      when Hash then from_page(body, wrap)
      when ::Array then new(data: body, wrap: wrap)
      when nil, "" then new
      else raise Error, "unexpected list payload: #{body.class}"
      end
    end

    def self.from_page(page, wrap)
      extras = page.reject { |key, _| PAGE_KEYS.include?(key.to_s) }
      new(data: page["items"] || [], next_cursor: page["nextCursor"], extras: extras, wrap: wrap)
    end
    private_class_method :from_page

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

    def last_page?
      next_cursor.nil? || next_cursor.to_s.empty?
    end

    def inspect
      "#<#{self.class.name} size=#{size} next_cursor=#{next_cursor.inspect}>"
    end
  end
end
