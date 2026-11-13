# frozen_string_literal: true

module DatabasusRuby
  # Base class for every error raised by this gem.
  class Error < StandardError; end

  # Raised when the client is missing something it needs before it can talk to
  # the API at all (a workspace id, a url, ...).
  class ConfigurationError < Error; end

  # Raised by Auth#signin when the account requires an emailed sign-in code
  # (two-factor). An unattended client cannot answer it; use an account
  # without 2FA or finish with Auth#verify_sign_in_code.
  class SignInCodeRequiredError < Error
    attr_reader :pending_sign_in_id, :email

    def initialize(pending_sign_in_id:, email:)
      @pending_sign_in_id = pending_sign_in_id
      @email = email
      super("sign-in for #{email} needs the emailed code (pending sign-in #{pending_sign_in_id})")
    end
  end

  # Raised when Databasus answers with a non-successful status code.
  #
  # Databasus answers errors as RFC 9457 problems:
  # `{ type, title, status, detail, code, errors }`. `code` is the stable
  # machine-readable reason (`database_connection_failed`,
  # `insufficient_disk_space`, `already_running`, ...).
  class APIError < Error
    attr_reader :status, :body, :response, :code

    def initialize(message = nil, status: nil, body: nil, response: nil, code: nil)
      @status = status
      @body = body
      @response = response
      @code = code
      super(message || "Databasus API returned #{status}")
    end

    # Maps a Faraday response onto the most specific error class available.
    # `body` overrides the response body (streamed responses carry none).
    def self.from_response(response, body: response.body)
      klass = for_status(response.status)
      klass.new(message_from(body), status: response.status, body: body, response: response, code: code_from(body))
    end

    def self.for_status(status)
      return ServerError if (500..599).cover?(status)

      STATUS_ERRORS.fetch(status, APIError)
    end

    # A validation problem's `detail` is generic ("the request breaks a
    # validation rule"); the field errors are what say which rule.
    def self.message_from(body)
      case body
      when Hash then problem_message(body)
      when String then body.empty? ? nil : body[0, 500]
      end
    end

    def self.problem_message(problem)
      message = problem["detail"] || problem["title"] || problem["error"] || problem["message"]
      fields = Array(problem["errors"]).filter_map { |e| "#{e["field"]}: #{e["detail"]}" if e.is_a?(Hash) }
      fields.empty? ? message : [message, fields.join("; ")].compact.join(" — ")
    end

    def self.code_from(body)
      body["code"] if body.is_a?(Hash)
    end
    private_class_method :message_from, :problem_message, :code_from
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
