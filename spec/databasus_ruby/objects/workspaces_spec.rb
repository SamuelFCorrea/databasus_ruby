# frozen_string_literal: true

RSpec.describe DatabasusRuby::Workspaces do
  subject(:workspaces) { client.workspaces }

  describe "#list" do
    it "reads the unpaginated envelope" do
      stub_api(:get, "workspaces", body: {
                 "workspaces" => [
                   { "id" => "ws-1", "name" => "production", "userRole" => "WORKSPACE_OWNER" },
                   { "id" => "ws-2", "name" => "staging", "userRole" => "WORKSPACE_VIEWER" }
                 ]
               })

      result = workspaces.list

      expect(result.total).to eq(2)
      expect(result.map(&:name)).to eq(%w[production staging])
      expect(result.first.userRole).to eq("WORKSPACE_OWNER")
      expect(result).not_to be_paginated
    end

    it "handles a user who belongs to none" do
      stub_api(:get, "workspaces", body: { "workspaces" => [] })

      expect(workspaces.list).to be_empty
    end
  end

  describe "crud" do
    it "creates" do
      stub_api(:post, "workspaces", body: { "id" => "ws-9", "name" => "production" })

      expect(workspaces.create(name: "production").id).to eq("ws-9")
      expect(WebMock).to have_requested(:post, api_url("workspaces")).with(body: { "name" => "production" })
    end

    it "reads" do
      stub_api(:get, "workspaces/ws-1", body: { "id" => "ws-1", "name" => "production" })

      expect(workspaces.get("ws-1").name).to eq("production")
    end

    it "updates" do
      stub_api(:put, "workspaces/ws-1", body: { "id" => "ws-1", "name" => "renamed" })

      expect(workspaces.update("ws-1", name: "renamed").name).to eq("renamed")
      expect(WebMock).to have_requested(:put, api_url("workspaces/ws-1")).with(body: { "name" => "renamed" })
    end

    it "deletes" do
      stub_api(:delete, "workspaces/ws-1", body: { "message" => "deleted" })

      expect(workspaces.delete("ws-1")).to be(true)
    end
  end

  describe "#audit_logs" do
    it "reads the paginated envelope under auditLogs" do
      stub_api(:get, "workspaces/ws-1/audit-logs", query: { "limit" => "1", "offset" => "0" }, body: {
                 "auditLogs" => [{ "id" => "a1", "action" => "DATABASE_CREATED" }],
                 "total" => 9, "limit" => 1, "offset" => 0
               })

      result = workspaces.audit_logs("ws-1", limit: 1, offset: 0)

      expect(result.first.action).to eq("DATABASE_CREATED")
      expect(result.total).to eq(9)
      expect(result.next_offset).to eq(1)
    end
  end

  describe "membership" do
    it "lists members under the memberships path" do
      stub_api(:get, "workspaces/memberships/ws-1/members", body: {
                 "members" => [
                   { "userId" => "u1", "email" => "owner@example.com", "role" => "WORKSPACE_OWNER" },
                   { "userId" => "u2", "email" => "dev@example.com", "role" => "WORKSPACE_MEMBER" }
                 ]
               })

      result = workspaces.members("ws-1")

      expect(result.total).to eq(2)
      expect(result.map(&:email)).to eq(["owner@example.com", "dev@example.com"])
      expect(result.first.user_id).to eq("u1")
    end

    it "adds an existing user" do
      stub_api(:post, "workspaces/memberships/ws-1/members", body: { "status" => "ADDED" })

      result = workspaces.add_member("ws-1", email: "dev@example.com", role: "WORKSPACE_MEMBER")

      expect(result.status).to eq("ADDED")
      expect(WebMock).to have_requested(:post, api_url("workspaces/memberships/ws-1/members"))
        .with(body: { "email" => "dev@example.com", "role" => "WORKSPACE_MEMBER" })
    end

    it "reports an invitation for a user who does not exist yet" do
      stub_api(:post, "workspaces/memberships/ws-1/members", body: { "status" => "INVITED" })

      expect(workspaces.add_member("ws-1", email: "new@example.com", role: "WORKSPACE_VIEWER").status)
        .to eq("INVITED")
    end

    it "removes a member" do
      stub_api(:delete, "workspaces/memberships/ws-1/members/u2", body: {})

      expect(workspaces.remove_member("ws-1", "u2")).to be(true)
    end

    it "changes a member role" do
      stub_api(:put, "workspaces/memberships/ws-1/members/u2/role", body: {})

      expect(workspaces.change_member_role("ws-1", "u2", role: "WORKSPACE_ADMIN")).to be(true)
      expect(WebMock).to have_requested(:put, api_url("workspaces/memberships/ws-1/members/u2/role"))
        .with(body: { "role" => "WORKSPACE_ADMIN" })
    end

    it "transfers ownership" do
      stub_api(:post, "workspaces/memberships/ws-1/transfer-ownership", body: {})

      expect(workspaces.transfer_ownership("ws-1", new_owner_email: "boss@example.com")).to be(true)
      expect(WebMock).to have_requested(:post, api_url("workspaces/memberships/ws-1/transfer-ownership"))
        .with(body: { "newOwnerEmail" => "boss@example.com" })
    end

    it "requires both ids" do
      expect { workspaces.remove_member("ws-1", nil) }.to raise_error(ArgumentError, /id is required/)
    end
  end

  it "exposes the documented member roles" do
    expect(described_class::MEMBER_ROLES).to include("WORKSPACE_OWNER", "WORKSPACE_VIEWER")
  end
end
