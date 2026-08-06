# frozen_string_literal: true

RSpec.describe DatabasusRuby::Users do
  subject(:users) { client.users }

  describe "the current user" do
    it "reads the profile" do
      stub_api(:get, "users/me", body: {
                 "id" => "u1", "email" => "me@example.com", "name" => "Me",
                 "role" => "ADMIN", "isActive" => true
               })

      me = users.me

      expect(me.email).to eq("me@example.com")
      expect(me.role).to eq("ADMIN")
      expect(me.isActive).to be(true)
    end

    it "updates only the fields given" do
      stub_api(:put, "users/me", body: {})

      users.update_me(name: "Renamed")

      expect(WebMock).to have_requested(:put, api_url("users/me")).with(body: { "name" => "Renamed" })
    end

    it "changes the password" do
      stub_api(:put, "users/change-password", body: {})

      users.change_password(new_password: "brand-new")

      expect(WebMock).to have_requested(:put, api_url("users/change-password"))
        .with(body: { "newPassword" => "brand-new" })
    end
  end

  describe "#invite" do
    it "invites without a workspace" do
      stub_api(:post, "users/invite", body: { "id" => "i1", "email" => "new@example.com" })

      expect(users.invite(email: "new@example.com").id).to eq("i1")
      expect(WebMock).to have_requested(:post, api_url("users/invite"))
        .with(body: { "email" => "new@example.com" })
    end

    it "invites straight into a workspace role" do
      stub_api(:post, "users/invite", body: {})

      users.invite(email: "new@example.com", intended_workspace_id: "ws-1",
                   intended_workspace_role: "WORKSPACE_VIEWER")

      expect(WebMock).to have_requested(:post, api_url("users/invite")).with(
        body: {
          "email" => "new@example.com",
          "intendedWorkspaceId" => "ws-1",
          "intendedWorkspaceRole" => "WORKSPACE_VIEWER"
        }
      )
    end
  end

  describe "administration" do
    it "lists users from the envelope" do
      stub_api(:get, "users", query: { "limit" => "2", "query" => "ops" }, body: {
                 "users" => [{ "id" => "u1", "name" => "Ops" }, { "id" => "u2", "name" => "Ops Two" }],
                 "total" => 5
               })

      result = users.list(limit: 2, query: "ops")

      expect(result.total).to eq(5)
      expect(result.map(&:name)).to eq(["Ops", "Ops Two"])
    end

    it "fetches one user" do
      stub_api(:get, "users/u1", body: { "id" => "u1", "createdAt" => "2026-01-01T00:00:00Z" })

      expect(users.get("u1").created_at).to eq("2026-01-01T00:00:00Z")
    end

    it "activates and deactivates" do
      stub_api(:post, "users/u1/activate", body: { "message" => "ok" })
      stub_api(:post, "users/u1/deactivate", body: { "message" => "ok" })

      expect(users.activate("u1")).to be(true)
      expect(users.deactivate("u1")).to be(true)
    end

    it "changes a role" do
      stub_api(:put, "users/u1/role", body: {})

      expect(users.change_role("u1", role: "ADMIN")).to be(true)
      expect(WebMock).to have_requested(:put, api_url("users/u1/role")).with(body: { "role" => "ADMIN" })
    end

    it "reports the 403 a member gets" do
      stub_api(:get, "users", status: 403, body: { "error" => "admin role required" })

      expect { users.list }.to raise_error(DatabasusRuby::ForbiddenError, "admin role required")
    end
  end

  describe "instance settings" do
    it "reads them" do
      stub_api(:get, "users/settings", body: {
                 "id" => "s1",
                 "isAllowExternalRegistrations" => false,
                 "isAllowMemberInvitations" => true,
                 "isMemberAllowedToCreateWorkspaces" => true
               })

      settings = users.settings

      expect(settings.isAllowExternalRegistrations).to be(false)
      expect(settings.is_allow_member_invitations).to be(true)
    end

    it "writes them" do
      stub_api(:put, "users/settings", body: {})

      users.update_settings(isAllowExternalRegistrations: true)

      expect(WebMock).to have_requested(:put, api_url("users/settings"))
        .with(body: { "isAllowExternalRegistrations" => true })
    end
  end

  it "exposes the documented roles" do
    expect(described_class::ROLES).to eq(%w[ADMIN MEMBER])
  end
end
