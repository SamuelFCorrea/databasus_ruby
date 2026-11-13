# frozen_string_literal: true

module DatabasusRuby
  # Notification channels.
  #
  #   client.notifiers.create(workspaceId: id, name: "ops", settings: { type: "SLACK", ... })
  #   client.notifiers.update(notifier.id, name: "ops", settings: { type: "SLACK", ... })
  class Notifiers < Object
    include Endpoint

    TYPES = %w[EMAIL TELEGRAM WEBHOOK SLACK DISCORD TEAMS].freeze

    # GET /notifiers
    def list(workspace_id: nil, limit: nil, after: nil)
      collection(http_get("notifiers",
                          { workspaceId: workspace_id || client.workspace_id!, limit: limit, after: after }))
    end
    alias all list

    # GET /notifiers/{id}
    def get(id)
      object(http_get("notifiers/#{escape(id)}"))
    end
    alias find get

    # POST /notifiers — `workspaceId`, `name` and the type-specific `settings`.
    def create(**attributes)
      object(http_post("notifiers", with_default_workspace(attributes)))
    end

    # PUT /notifiers/{id} — `name` and `settings`.
    def update(id, **attributes)
      object(http_put("notifiers/#{escape(id)}", attributes))
    end

    # DELETE /notifiers/{id}
    def delete(id)
      acknowledged(http_delete("notifiers/#{escape(id)}"))
    end

    # POST /notifiers/{id}/test — sends a test notification.
    def test(id)
      object(http_post("notifiers/#{escape(id)}/test"))
    end

    # POST /notifiers/{id}/transfer
    def transfer(id, target_workspace_id:)
      object(http_post("notifiers/#{escape(id)}/transfer", { targetWorkspaceId: target_workspace_id }))
    end
  end
end
