# frozen_string_literal: true

RSpec.describe DatabasusRuby::Auth do
  let(:completed) do
    { "outcome" => "COMPLETED", "userId" => "u1", "email" => "me@example.com", "token" => "jwt-1" }
  end

  describe "#signin" do
    it "posts the credentials to /sessions and returns the completed sign-in" do
      stub_api(:post, "sessions", body: completed)

      result = client(api_key: nil).auth.signin(email: "me@example.com", password: "secret")

      expect(result.token).to eq("jwt-1")
      expect(result.user_id).to eq("u1")
      expect(result.outcome).to eq("COMPLETED")
      expect(WebMock).to have_requested(:post, api_url("sessions"))
        .with(body: { "email" => "me@example.com", "password" => "secret" })
    end

    it "forwards the turnstile token when given" do
      stub_api(:post, "sessions", body: completed)

      client.auth.signin(email: "me@example.com", password: "secret", cloudflare_turnstile_token: "ts")

      expect(WebMock).to have_requested(:post, api_url("sessions"))
        .with(body: { "email" => "me@example.com", "password" => "secret", "cloudflareTurnstileToken" => "ts" })
    end

    it "installs the token so later calls are authorized" do
      stub_api(:post, "sessions", body: completed)
      stub_api(:get, "users/u1", body: { "id" => "u1" })
      instance = client(api_key: nil)

      instance.auth.signin(email: "me@example.com", password: "secret")
      instance.users.get("u1")

      expect(instance.api_key).to eq("jwt-1")
      expect(WebMock).to have_requested(:get, api_url("users/u1"))
        .with(headers: { "Authorization" => "Bearer jwt-1" })
    end

    it "raises SignInCodeRequiredError when the account needs the emailed code" do
      stub_api(:post, "sessions", body: {
                 "outcome" => "CODE_REQUIRED", "pendingSignInId" => "ps-1", "email" => "me@example.com"
               })
      instance = client(api_key: nil)

      expect { instance.auth.signin(email: "me@example.com", password: "secret") }
        .to raise_error(DatabasusRuby::SignInCodeRequiredError) do |error|
          expect(error.pending_sign_in_id).to eq("ps-1")
          expect(error.email).to eq("me@example.com")
          expect(error.message).to include("ps-1", "me@example.com")
        end
      expect(instance.api_key).to be_nil
    end

    it "raises when the response carries no token" do
      stub_api(:post, "sessions", body: { "outcome" => "COMPLETED", "userId" => "u1" })

      expect { client.auth.signin(email: "me@example.com", password: "secret") }
        .to raise_error(DatabasusRuby::Error, /did not return a token/)
    end

    it "lets the 401 problem through with its code" do
      stub_api(:post, "sessions", status: 401, body: {
                 "type" => "about:blank", "title" => "Unauthorized", "status" => 401,
                 "detail" => "the password is incorrect", "code" => "password_incorrect"
               })

      expect { client.auth.signin(email: "me@example.com", password: "nope") }
        .to raise_error(DatabasusRuby::AuthenticationError, "the password is incorrect") do |error|
          expect(error.code).to eq("password_incorrect")
        end
    end
  end

  describe "#verify_sign_in_code" do
    it "posts the code to the pending sign-in and installs the token" do
      stub_api(:post, "pending-sign-ins/ps-1/verify",
               body: { "userId" => "u1", "email" => "me@example.com", "token" => "jwt-2" })
      instance = client(api_key: nil)

      result = instance.auth.verify_sign_in_code("ps-1", code: "123456")

      expect(result.user_id).to eq("u1")
      expect(instance.api_key).to eq("jwt-2")
      expect(WebMock).to have_requested(:post, api_url("pending-sign-ins/ps-1/verify"))
        .with(body: { "code" => "123456" })
    end

    it "forwards the turnstile token when given" do
      stub_api(:post, "pending-sign-ins/ps-1/verify", body: { "token" => "jwt-2" })

      client.auth.verify_sign_in_code("ps-1", code: "123456", cloudflare_turnstile_token: "ts")

      expect(WebMock).to have_requested(:post, api_url("pending-sign-ins/ps-1/verify"))
        .with(body: { "code" => "123456", "cloudflareTurnstileToken" => "ts" })
    end

    it "requires the pending sign-in id" do
      expect { client.auth.verify_sign_in_code(nil, code: "123456") }.to raise_error(ArgumentError, /id is required/)
    end

    it "surfaces the 410 once the pending sign-in is no longer usable" do
      stub_api(:post, "pending-sign-ins/ps-1/verify", status: 410, body: {
                 "title" => "Gone", "status" => 410, "detail" => "the sign-in expired",
                 "code" => "pending_sign_in_not_usable"
               })

      expect { client.auth.verify_sign_in_code("ps-1", code: "000000") }
        .to raise_error(DatabasusRuby::APIError, "the sign-in expired") do |error|
          expect(error.status).to eq(410)
          expect(error.code).to eq("pending_sign_in_not_usable")
        end
    end
  end

  describe "#signup" do
    it "posts to /users and installs the token" do
      stub_api(:post, "users", status: 201,
                               body: { "userId" => "u2", "email" => "new@example.com", "token" => "jwt-3" })
      instance = client(api_key: nil)

      result = instance.auth.signup(email: "new@example.com", name: "New", password: "secret")

      expect(result.user_id).to eq("u2")
      expect(instance.api_key).to eq("jwt-3")
      expect(WebMock).to have_requested(:post, api_url("users"))
        .with(body: { "email" => "new@example.com", "name" => "New", "password" => "secret" })
    end

    it "raises when the response carries no token" do
      stub_api(:post, "users", status: 201, body: { "userId" => "u2" })

      expect { client.auth.signup(email: "new@example.com", name: "New", password: "secret") }
        .to raise_error(DatabasusRuby::Error, /did not return a token/)
    end
  end

  describe "password reset" do
    it "requests a reset code" do
      stub_request(:post, api_url("password-resets")).to_return(status: 202, body: "")

      expect(client.auth.request_password_reset(email: "me@example.com")).to be(true)
      expect(WebMock).to have_requested(:post, api_url("password-resets")).with(body: { "email" => "me@example.com" })
    end

    it "completes the reset with the emailed code" do
      stub_request(:post, api_url("password-reset-completions")).to_return(status: 204, body: "")

      expect(client.auth.reset_password(email: "me@example.com", code: "123456", new_password: "n3w")).to be(true)
      expect(WebMock).to have_requested(:post, api_url("password-reset-completions"))
        .with(body: { "email" => "me@example.com", "code" => "123456", "newPassword" => "n3w" })
    end
  end
end
