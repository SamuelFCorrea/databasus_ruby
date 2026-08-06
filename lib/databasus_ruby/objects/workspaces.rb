# frozen_string_literal: true

module DatabasusRuby
  # Workspaces, their members and their audit trail.
  #
  #   workspace = client.workspaces.create(name: "production")
  #   client.workspaces.add_member(workspace.id, email: "ops@example.com",
  #                                role: "WORKSPACE_ADMIN")
  #
  # Note that the membership endpoints live under /workspaces/memberships/{id},
  # where {id} is still the workspace id.
  class Workspaces < Object
    include Endpoint

    MEMBER_ROLES = %w[WORKSPACE_OWNER WORKSPACE_ADMIN WORKSPACE_MEMBER WORKSPACE_VIEWER].freeze

    # GET /workspaces — the workspaces the current user belongs to.
    def list
      collection(http_get("workspaces"), key: "workspaces")
    end

    alias all list

    # POST /workspaces
    def create(name:)
      object(http_post("workspaces", { name: name }))
    end

    # GET /workspaces/{id}
    def get(id)
      object(http_get("workspaces/#{escape(id)}"))
    end
    alias find get

    # PUT /workspaces/{id}
    def update(id, **attributes)
      object(http_put("workspaces/#{escape(id)}", attributes))
    end

    # DELETE /workspaces/{id}
    def delete(id)
      acknowledged(http_delete("workspaces/#{escape(id)}"))
    end

    # GET /workspaces/{id}/audit-logs
    def audit_logs(id, limit: nil, offset: nil, before_date: nil)
      response = http_get("workspaces/#{escape(id)}/audit-logs",
                          { limit: limit, offset: offset, beforeDate: before_date })
      collection(response, key: "auditLogs")
    end

    # GET /workspaces/memberships/{id}/members
    def members(id)
      collection(http_get("workspaces/memberships/#{escape(id)}/members"), key: "members")
    end

    # POST /workspaces/memberships/{id}/members — adds an existing user or
    # invites a new one; the response `status` says which happened
    # (ADDED or INVITED). `role` is one of MEMBER_ROLES.
    def add_member(id, email:, role:)
      object(http_post("workspaces/memberships/#{escape(id)}/members", { email: email, role: role }))
    end

    # DELETE /workspaces/memberships/{id}/members/{userId}
    def remove_member(id, user_id)
      acknowledged(http_delete("workspaces/memberships/#{escape(id)}/members/#{escape(user_id)}"))
    end

    # PUT /workspaces/memberships/{id}/members/{userId}/role
    def change_member_role(id, user_id, role:)
      acknowledged(http_put("workspaces/memberships/#{escape(id)}/members/#{escape(user_id)}/role",
                            { role: role }))
    end

    # POST /workspaces/memberships/{id}/transfer-ownership
    def transfer_ownership(id, new_owner_email:)
      acknowledged(http_post("workspaces/memberships/#{escape(id)}/transfer-ownership",
                             { newOwnerEmail: new_owner_email }))
    end
  end
end
