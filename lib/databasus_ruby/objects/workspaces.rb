# frozen_string_literal: true

module DatabasusRuby
  # Workspaces, their members and their audit trail.
  #
  #   workspace = client.workspaces.create(name: "production")
  #   client.workspaces.add_member(workspace.id, email: "ops@example.com", role: "WORKSPACE_ADMIN")
  #
  # Members are addressed by their member id (from #members), not their user id.
  class Workspaces < Object
    include Endpoint

    MEMBER_ROLES = %w[WORKSPACE_OWNER WORKSPACE_ADMIN WORKSPACE_MEMBER WORKSPACE_VIEWER].freeze

    # GET /workspaces — the workspaces the current user belongs to.
    def list(limit: nil, after: nil)
      collection(http_get("workspaces", { limit: limit, after: after }))
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
    def update(id, name:)
      object(http_put("workspaces/#{escape(id)}", { name: name }))
    end

    # DELETE /workspaces/{id}
    def delete(id)
      acknowledged(http_delete("workspaces/#{escape(id)}"))
    end

    # POST /workspaces/{id}/transfer-ownership
    def transfer_ownership(id, new_owner_member_id:)
      acknowledged(http_post("workspaces/#{escape(id)}/transfer-ownership", { newOwnerMemberId: new_owner_member_id }))
    end

    # GET /audit-events
    def audit_events(id, author_user_id: nil, limit: nil, after: nil)
      collection(http_get("audit-events", {
                            workspaceId: require_id(id), authorUserId: author_user_id, limit: limit, after: after
                          }))
    end

    # GET /workspace-members
    def members(id, limit: nil, after: nil)
      collection(http_get("workspace-members", { workspaceId: require_id(id), limit: limit, after: after }))
    end

    # POST /workspace-members — `role` is one of MEMBER_ROLES except the owner.
    def add_member(id, email:, role:)
      object(http_post("workspace-members", { workspaceId: require_id(id), email: email, role: role }))
    end

    # DELETE /workspace-members/{memberId}
    def remove_member(member_id)
      acknowledged(http_delete("workspace-members/#{escape(member_id)}"))
    end

    # PUT /workspace-members/{memberId}
    def change_member_role(member_id, role:)
      object(http_put("workspace-members/#{escape(member_id)}", { role: role }))
    end
  end
end
