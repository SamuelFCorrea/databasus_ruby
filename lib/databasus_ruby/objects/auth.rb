# frozen_string_literal: true

module DatabasusRuby
  # Obtaining a session token. Every other endpoint needs the token these
  # methods return, so a completed sign-in installs it on the client as
  # `api_key`.
  #
  #   client.auth.signin(email: "me@example.com", password: "secret")
  #   client.databases.list(workspace_id: id)
  #
  # An account with two-factor sign-in answers CODE_REQUIRED: #signin raises
  # SignInCodeRequiredError and #verify_sign_in_code finishes it.
  class Auth < Object
    include Endpoint

    # POST /sessions
    #
    # @return [DatabasusRuby::Object] the completed sign-in (`token`, `userId`, `email`)
    # @raise [DatabasusRuby::SignInCodeRequiredError] when the account needs the emailed code
    def signin(email:, password:, cloudflare_turnstile_token: nil)
      outcome = object(http_post("sessions", {
                                   email: email,
                                   password: password,
                                   cloudflareTurnstileToken: cloudflare_turnstile_token
                                 }))
      if outcome.outcome == "CODE_REQUIRED"
        raise SignInCodeRequiredError.new(pending_sign_in_id: outcome.pending_sign_in_id, email: outcome.email)
      end

      authorize outcome
    end

    # POST /pending-sign-ins/{id}/verify
    def verify_sign_in_code(pending_sign_in_id, code:, cloudflare_turnstile_token: nil)
      authorize object(http_post("pending-sign-ins/#{escape(pending_sign_in_id)}/verify", {
                                   code: code,
                                   cloudflareTurnstileToken: cloudflare_turnstile_token
                                 }))
    end

    # POST /users — self-registration, when the instance allows it.
    def signup(email:, name:, password:, cloudflare_turnstile_token: nil)
      authorize object(http_post("users", {
                                   email: email,
                                   name: name,
                                   password: password,
                                   cloudflareTurnstileToken: cloudflare_turnstile_token
                                 }))
    end

    # POST /password-resets — emails a reset code.
    def request_password_reset(email:, cloudflare_turnstile_token: nil)
      acknowledged(http_post("password-resets", { email: email, cloudflareTurnstileToken: cloudflare_turnstile_token }))
    end

    # POST /password-reset-completions
    def reset_password(email:, code:, new_password:)
      acknowledged(http_post("password-reset-completions", { email: email, code: code, newPassword: new_password }))
    end

    private

    def authorize(result)
      token = result.token
      raise Error, "Databasus did not return a token" if token.nil? || token.empty?

      client.api_key = token
      result
    end
  end
end
