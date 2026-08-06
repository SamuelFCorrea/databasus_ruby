# frozen_string_literal: true

RSpec.describe DatabasusRuby::Auth do
  describe "#signin" do
    it "returns the decoded payload" do
      stub_api(:post, "users/signin", body: { "token" => "jwt-1", "userId" => "u1", "email" => "me@example.com" })

      result = client(api_key: nil).auth.signin(email: "me@example.com", password: "secret")

      expect(result.token).to eq("jwt-1")
      expect(result.user_id).to eq("u1")
      expect(WebMock).to have_requested(:post, api_url("users/signin"))
        .with(body: { "email" => "me@example.com", "password" => "secret" })
    end

    it "forwards the turnstile token when given" do
      stub_api(:post, "users/signin", body: { "token" => "jwt-1" })

      client.auth.signin(email: "me@example.com", password: "secret", cloudflare_turnstile_token: "ts")

      expect(WebMock).to have_requested(:post, api_url("users/signin"))
        .with(body: { "email" => "me@example.com", "password" => "secret", "cloudflareTurnstileToken" => "ts" })
    end

    it "installs the token so later calls are authorized" do
      stub_api(:post, "users/signin", body: { "token" => "jwt-1" })
      stub_api(:get, "users/me", body: { "id" => "u1" })
      instance = client(api_key: nil)

      instance.auth.signin(email: "me@example.com", password: "secret")
      instance.users.me

      expect(instance.api_key).to eq("jwt-1")
      expect(WebMock).to have_requested(:get, api_url("users/me"))
        .with(headers: { "Authorization" => "Bearer jwt-1" })
    end

    it "raises when the response carries no token" do
      stub_api(:post, "users/signin", body: { "userId" => "u1" })

      expect { client.auth.signin(email: "me@example.com", password: "secret") }
        .to raise_error(DatabasusRuby::Error, /did not return a token/)
    end

    it "lets the 400 through unchanged" do
      stub_api(:post, "users/signin", status: 400, body: { "error" => "invalid credentials" })

      expect { client.auth.signin(email: "me@example.com", password: "nope") }
        .to raise_error(DatabasusRuby::BadRequestError, "invalid credentials")
    end
  end

  describe "#signup" do
    it "registers and installs the token" do
      stub_api(:post, "users/signup", body: { "token" => "jwt-2", "userId" => "u2" })
      instance = client(api_key: nil)

      result = instance.auth.signup(email: "new@example.com", name: "New", password: "secret")

      expect(result.user_id).to eq("u2")
      expect(instance.api_key).to eq("jwt-2")
      expect(WebMock).to have_requested(:post, api_url("users/signup"))
        .with(body: { "email" => "new@example.com", "name" => "New", "password" => "secret" })
    end

    it "forwards the turnstile token when given" do
      stub_api(:post, "users/signup", body: { "token" => "jwt-2" })

      client.auth.signup(email: "new@example.com", name: "New", password: "secret", cloudflare_turnstile_token: "ts")

      expect(WebMock).to have_requested(:post, api_url("users/signup")).with(
        body: {
          "email" => "new@example.com", "name" => "New", "password" => "secret", "cloudflareTurnstileToken" => "ts"
        }
      )
    end

    it "raises when the response carries no token" do
      stub_api(:post, "users/signup", body: { "userId" => "u2" })

      expect { client.auth.signup(email: "new@example.com", name: "New", password: "secret") }
        .to raise_error(DatabasusRuby::Error, /did not return a token/)
    end

    it "lets the 409 through unchanged" do
      stub_api(:post, "users/signup", status: 409, body: { "error" => "email already registered" })

      expect { client.auth.signup(email: "taken@example.com", name: "New", password: "secret") }
        .to raise_error(DatabasusRuby::ConflictError, "email already registered")
    end
  end

  describe "oauth callbacks" do
    it "exchanges a github code" do
      stub_api(:post, "auth/github/callback", body: { "token" => "jwt-3", "isNewUser" => true })

      result = client.auth.github_callback(code: "code-1", redirect_uri: "https://app.test/cb")

      expect(result.isNewUser).to be(true)
      expect(WebMock).to have_requested(:post, api_url("auth/github/callback"))
        .with(body: { "code" => "code-1", "redirectUri" => "https://app.test/cb" })
    end

    it "exchanges a google code" do
      stub_api(:post, "auth/google/callback", body: { "token" => "jwt-4" })

      expect(client.auth.google_callback(code: "code-2", redirect_uri: "https://app.test/cb").token)
        .to eq("jwt-4")
    end

    it "reports a provider that is not configured" do
      stub_api(:post, "auth/github/callback", status: 501, body: { "error" => "github oauth is not configured" })

      expect { client.auth.github_callback(code: "c", redirect_uri: "u") }
        .to raise_error(DatabasusRuby::APIError, "github oauth is not configured")
    end
  end

  describe "password reset" do
    it "requests a code" do
      stub_api(:post, "users/send-reset-password-code", body: {})

      client.auth.send_reset_password_code(email: "me@example.com")

      expect(WebMock).to have_requested(:post, api_url("users/send-reset-password-code"))
        .with(body: { "email" => "me@example.com" })
    end

    it "surfaces the throttle" do
      stub_api(:post, "users/send-reset-password-code", status: 429, body: { "error" => "too many requests" })

      expect { client.auth.send_reset_password_code(email: "me@example.com") }
        .to raise_error(DatabasusRuby::RateLimitError, "too many requests")
    end

    it "redeems the code" do
      stub_api(:post, "users/reset-password", body: {})

      client.auth.reset_password(email: "me@example.com", code: "123456", new_password: "brand-new")

      expect(WebMock).to have_requested(:post, api_url("users/reset-password"))
        .with(body: { "email" => "me@example.com", "code" => "123456", "newPassword" => "brand-new" })
    end
  end
end
