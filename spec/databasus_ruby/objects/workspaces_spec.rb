# frozen_string_literal: true

RSpec.describe DatabasusRuby::Workspaces do
  subject(:workspaces) { client.workspaces }

  let(:workspace) { { "id" => "ws-1", "name" => "production", "createdAt" => "2026-01-01T00:00:00Z" } }

  describe "#list" do
    it "reads the cursor page" do
      stub_api(:get, "workspaces", query: { "limit" => "2" }, body: {
                 "items" => [workspace, { "id" => "ws-2", "name" => "staging" }], "nextCursor" => "cur-2"
               })

      result = workspaces.list(limit: 2)

      expect(result.map(&:name)).to eq(%w[production staging])
      expect(result.next_cursor).to eq("cur-2")
    end

    it "handles a user who belongs to none" do
      stub_api(:get, "workspaces", body: { "items" => [] })

      expect(workspaces.list).to be_empty
    end
  end

  describe "crud" do
    it "creates" do
      stub_api(:post, "workspaces", status: 201, body: workspace)

      expect(workspaces.create(name: "production").id).to eq("ws-1")
      expect(WebMock).to have_requested(:post, api_url("workspaces")).with(body: { "name" => "production" })
    end

    it "reads" do
      stub_api(:get, "workspaces/ws-1", body: workspace)

      expect(workspaces.get("ws-1").name).to eq("production")
      expect(workspaces.find("ws-1").id).to eq("ws-1")
    end

    it "updates" do
      stub_api(:put, "workspaces/ws-1", body: workspace.merge("name" => "prod"))

      expect(workspaces.update("ws-1", name: "prod").name).to eq("prod")
      expect(WebMock).to have_requested(:put, api_url("workspaces/ws-1")).with(body: { "name" => "prod" })
    end

    it "deletes" do
      stub_request(:delete, api_url("workspaces/ws-1")).to_return(status: 204, body: "")

      expect(workspaces.delete("ws-1")).to be(true)
    end
  end

  describe "#transfer_ownership" do
    it "posts the new owner's member id" do
      stub_request(:post, api_url("workspaces/ws-1/transfer-ownership")).to_return(status: 204, body: "")

      expect(workspaces.transfer_ownership("ws-1", new_owner_member_id: "m-2")).to be(true)
      expect(WebMock).to have_requested(:post, api_url("workspaces/ws-1/transfer-ownership"))
        .with(body: { "newOwnerMemberId" => "m-2" })
    end
  end

  describe "#audit_events" do
    it "reads /audit-events filtered by workspace and author" do
      query = { "workspaceId" => "ws-1", "authorUserId" => "u1", "limit" => "50" }
      stub_api(:get, "audit-events", query: query, body: {
                 "items" => [{ "id" => "e1", "message" => "database created", "author" => { "id" => "u1" } }]
               })

      result = workspaces.audit_events("ws-1", author_user_id: "u1", limit: 50)

      expect(result.first.message).to eq("database created")
      expect(result.first.author.id).to eq("u1")
    end

    it "requires the workspace id" do
      expect { workspaces.audit_events(nil) }.to raise_error(ArgumentError, /id is required/)
    end
  end

  describe "members" do
    it "lists through /workspace-members" do
      stub_api(:get, "workspace-members", query: { "workspaceId" => "ws-1" }, body: {
                 "items" => [{ "id" => "m-1", "userId" => "u1", "role" => "WORKSPACE_OWNER" }]
               })

      expect(workspaces.members("ws-1").first.role).to eq("WORKSPACE_OWNER")
    end

    it "adds a member" do
      stub_api(:post, "workspace-members", status: 201, body: { "id" => "m-2", "role" => "WORKSPACE_ADMIN" })

      expect(workspaces.add_member("ws-1", email: "ops@example.com", role: "WORKSPACE_ADMIN").id).to eq("m-2")
      expect(WebMock).to have_requested(:post, api_url("workspace-members"))
        .with(body: { "workspaceId" => "ws-1", "email" => "ops@example.com", "role" => "WORKSPACE_ADMIN" })
    end

    it "changes a member's role by member id" do
      stub_api(:put, "workspace-members/m-2", body: { "id" => "m-2", "role" => "WORKSPACE_VIEWER" })

      expect(workspaces.change_member_role("m-2", role: "WORKSPACE_VIEWER").role).to eq("WORKSPACE_VIEWER")
      expect(WebMock).to have_requested(:put, api_url("workspace-members/m-2"))
        .with(body: { "role" => "WORKSPACE_VIEWER" })
    end

    it "removes a member by member id" do
      stub_request(:delete, api_url("workspace-members/m-2")).to_return(status: 204, body: "")

      expect(workspaces.remove_member("m-2")).to be(true)
    end
  end

  it "exposes the documented member roles" do
    expect(described_class::MEMBER_ROLES).to include("WORKSPACE_OWNER", "WORKSPACE_VIEWER")
  end
end
