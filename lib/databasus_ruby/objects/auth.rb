# frozen_string_literal: true

module DatabasusRuby
  # Obtaining a token. Every other endpoint needs the JWT these methods
  # return, so #signin and #signup install it on the client as `api_key`.
  #
  #   client.auth.signin(email: "me@example.com", password: "secret")
  #   client.users.me.name
  #
  # Read the token off the result if you want to keep it for a later client.
  class Auth < Object
    include Endpoint

    # POST /users/signin
    def signin(email:, password:, cloudflare_turnstile_token: nil)
      authorize object(http_post("users/signin", {
                                   email: email,
                                   password: password,
                                   cloudflareTurnstileToken: cloudflare_turnstile_token
                                 }))
    end

    # POST /users/signup
    def signup(email:, name:, password:, cloudflare_turnstile_token: nil)
      authorize object(http_post("users/signup", {
                                   email: email,
                                   name: name,
                                   password: password,
                                   cloudflareTurnstileToken: cloudflare_turnstile_token
                                 }))
    end

    # POST /auth/github/callback
    def github_callback(code:, redirect_uri:)
      object(http_post("auth/github/callback", { code: code, redirectUri: redirect_uri }))
    end

    # POST /auth/google/callback
    def google_callback(code:, redirect_uri:)
      object(http_post("auth/google/callback", { code: code, redirectUri: redirect_uri }))
    end

    # POST /users/send-reset-password-code
    def send_reset_password_code(email:, cloudflare_turnstile_token: nil)
      object(http_post("users/send-reset-password-code", {
                         email: email,
                         cloudflareTurnstileToken: cloudflare_turnstile_token
                       }))
    end

    # POST /users/reset-password
    def reset_password(email:, code:, new_password:)
      object(http_post("users/reset-password", { email: email, code: code, newPassword: new_password }))
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
