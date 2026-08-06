# frozen_string_literal: true

module DatabasusRuby
  # Base class for every error raised by this gem.
  class Error < StandardError; end

  # Raised when the client is missing something it needs before it can talk to
  # the API at all (an agent id, a workspace id, ...).
  class ConfigurationError < Error; end

  # Raised when Databasus answers with a non-successful status code.
  class APIError < Error
    attr_reader :status, :body, :response

    def initialize(message = nil, status: nil, body: nil, response: nil)
      @status = status
      @body = body
      @response = response
      super(message || "Databasus API returned #{status}")
    end

    # Maps a Faraday response onto the most specific error class available.
    def self.from_response(response)
      klass = for_status(response.status)
      klass.new(message_from(response.body), status: response.status, body: response.body, response: response)
    end

    def self.for_status(status)
      return ServerError if (500..599).cover?(status)

      STATUS_ERRORS.fetch(status, APIError)
    end

    # Every handler in the Go backend answers errors as {"error": "..."}, but
    # streaming endpoints can still fail with a plain-text body.
    def self.message_from(body)
      case body
      when Hash then body["error"] || body["message"] || body[:error]
      when String then body.empty? ? nil : body[0, 500]
      end
    end
    private_class_method :message_from
  end

  class BadRequestError < APIError; end
  class AuthenticationError < APIError; end
  class ForbiddenError < APIError; end
  class NotFoundError < APIError; end
  class ConflictError < APIError; end
  class RateLimitError < APIError; end
  class ServerError < APIError; end

  class APIError
    STATUS_ERRORS = {
      400 => BadRequestError,
      401 => AuthenticationError,
      403 => ForbiddenError,
      404 => NotFoundError,
      409 => ConflictError,
      429 => RateLimitError
    }.freeze
  end
end
