# frozen_string_literal: true

RSpec.describe DatabasusRuby::Users do
  subject(:users) { client.users }

  let(:user) do
    { "id" => "u1", "email" => "me@example.com", "name" => "Me", "role" => "ADMIN", "status" => "ACTIVE",
      "createdAt" => "2026-01-01T00:00:00Z" }
  end

  describe "#list" do
    it "reads the cursor page with the search query" do
      stub_api(:get, "users", query: { "query" => "me", "limit" => "25" },
                              body: { "items" => [user], "nextCursor" => "c" })

      result = users.list(query: "me", limit: 25)

      expect(result.first.email).to eq("me@example.com")
      expect(result.next_cursor).to eq("c")
    end

    it "sends no query parameters by default" do
      stub_api(:get, "users", body: { "items" => [] })

      expect(users.all).to be_empty
    end

    it "lets the 403 for a MEMBER token through" do
      stub_api(:get, "users", status: 403, body: { "title" => "Forbidden", "status" => 403, "detail" => "admins only" })

      expect { users.list }.to raise_error(DatabasusRuby::ForbiddenError, "admins only")
    end
  end

  describe "#get and #update" do
    it "reads one user" do
      stub_api(:get, "users/u1", body: user)

      expect(users.get("u1").role).to eq("ADMIN")
      expect(users.find("u1").id).to eq("u1")
    end

    it "updates the name and email" do
      stub_api(:put, "users/u1", body: user.merge("name" => "New"))

      expect(users.update("u1", name: "New", email: "me@example.com").name).to eq("New")
      expect(WebMock).to have_requested(:put, api_url("users/u1"))
        .with(body: { "name" => "New", "email" => "me@example.com" })
    end
  end

  describe "account actions" do
    it "changes the password" do
      stub_request(:put, api_url("users/u1/password")).to_return(status: 204, body: "")

      expect(users.change_password("u1", new_password: "n3w")).to be(true)
      expect(WebMock).to have_requested(:put, api_url("users/u1/password")).with(body: { "newPassword" => "n3w" })
    end

    it "activates and deactivates" do
      stub_request(:post, api_url("users/u1/activate")).to_return(status: 204, body: "")
      stub_request(:post, api_url("users/u1/deactivate")).to_return(status: 204, body: "")

      expect(users.activate("u1")).to be(true)
      expect(users.deactivate("u1")).to be(true)
    end

    it "changes the role" do
      stub_request(:put, api_url("users/u1/role")).to_return(status: 204, body: "")

      expect(users.change_role("u1", role: "MEMBER")).to be(true)
      expect(WebMock).to have_requested(:put, api_url("users/u1/role")).with(body: { "role" => "MEMBER" })
    end
  end

  describe "instance settings" do
    it "reads them" do
      stub_api(:get, "instance-settings", body: { "isAllowExternalRegistrations" => false })

      expect(users.settings.is_allow_external_registrations).to be(false)
    end

    it "updates them" do
      stub_api(:put, "instance-settings", body: { "isAllowExternalRegistrations" => true })

      expect(users.update_settings(isAllowExternalRegistrations: true).is_allow_external_registrations).to be(true)
      expect(WebMock).to have_requested(:put, api_url("instance-settings"))
        .with(body: { "isAllowExternalRegistrations" => true })
    end
  end

  it "exposes the documented roles" do
    expect(described_class::ROLES).to eq(%w[ADMIN MEMBER])
  end
end
