# frozen_string_literal: true

module DatabasusRuby
  # The signed-in user, instance-wide user administration and instance
  # settings.
  #
  #   client.users.me.email
  #   client.users.list(query: "ops", limit: 25).each { |user| ... }
  #
  # The #list / #get / #activate / #deactivate / #change_role and settings
  # methods are ADMIN-only and answer 403 for a MEMBER token.
  class Users < Object
    include Endpoint

    ROLES = %w[ADMIN MEMBER].freeze

    # GET /users/me
    def me
      object(http_get("users/me"))
    end

    # PUT /users/me
    def update_me(name: nil, email: nil)
      object(http_put("users/me", { name: name, email: email }))
    end

    # PUT /users/change-password
    def change_password(new_password:)
      object(http_put("users/change-password", { newPassword: new_password }))
    end

    # POST /users/invite
    def invite(email:, intended_workspace_id: nil, intended_workspace_role: nil)
      object(http_post("users/invite", {
                         email: email,
                         intendedWorkspaceId: intended_workspace_id,
                         intendedWorkspaceRole: intended_workspace_role
                       }))
    end

    # GET /users (ADMIN)
    def list(limit: nil, offset: nil, before_date: nil, query: nil)
      response = http_get("users", { limit: limit, offset: offset, beforeDate: before_date, query: query })
      collection(response, key: "users")
    end
    alias all list

    # GET /users/{id} (ADMIN)
    def get(id)
      object(http_get("users/#{escape(id)}"))
    end
    alias find get

    # POST /users/{id}/activate (ADMIN)
    def activate(id)
      acknowledged(http_post("users/#{escape(id)}/activate"))
    end

    # POST /users/{id}/deactivate (ADMIN)
    def deactivate(id)
      acknowledged(http_post("users/#{escape(id)}/deactivate"))
    end

    # PUT /users/{id}/role (ADMIN) — role is one of ROLES.
    def change_role(id, role:)
      acknowledged(http_put("users/#{escape(id)}/role", { role: role }))
    end

    # GET /users/settings (ADMIN) — instance-wide registration settings.
    def settings
      object(http_get("users/settings"))
    end

    # PUT /users/settings (ADMIN)
    def update_settings(**attributes)
      object(http_put("users/settings", attributes))
    end
  end
end
