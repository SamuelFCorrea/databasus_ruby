# frozen_string_literal: true

module DatabasusRuby
  # Instance-wide user administration and instance settings.
  #
  #   client.users.list(query: "ops", limit: 25).each { |user| ... }
  #
  # Everything here except #update and #change_password on your own user is
  # ADMIN-only and answers 403 for a MEMBER token.
  class Users < Object
    include Endpoint

    ROLES = %w[ADMIN MEMBER].freeze

    # GET /users
    def list(query: nil, limit: nil, after: nil)
      collection(http_get("users", { query: query, limit: limit, after: after }))
    end
    alias all list

    # GET /users/{id}
    def get(id)
      object(http_get("users/#{escape(id)}"))
    end
    alias find get

    # PUT /users/{id}
    def update(id, name:, email:)
      object(http_put("users/#{escape(id)}", { name: name, email: email }))
    end

    # PUT /users/{id}/password
    def change_password(id, new_password:)
      acknowledged(http_put("users/#{escape(id)}/password", { newPassword: new_password }))
    end

    # POST /users/{id}/activate
    def activate(id)
      acknowledged(http_post("users/#{escape(id)}/activate"))
    end

    # POST /users/{id}/deactivate
    def deactivate(id)
      acknowledged(http_post("users/#{escape(id)}/deactivate"))
    end

    # PUT /users/{id}/role — role is one of ROLES.
    def change_role(id, role:)
      acknowledged(http_put("users/#{escape(id)}/role", { role: role }))
    end

    # GET /instance-settings
    def settings
      object(http_get("instance-settings"))
    end

    # PUT /instance-settings
    def update_settings(**attributes)
      object(http_put("instance-settings", attributes))
    end
  end
end
