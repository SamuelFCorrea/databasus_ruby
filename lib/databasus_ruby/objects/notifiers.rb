# frozen_string_literal: true

module DatabasusRuby
  # Notification channels.
  #
  #   client.notifiers.save(name: "ops", notifierType: "SLACK",
  #                         workspaceId: id, slackNotifier: { ... })
  #
  # POST /notifiers both creates and updates: include `id` in the payload to
  # update an existing notifier.
  class Notifiers < Object
    include Endpoint

    TYPES = %w[EMAIL TELEGRAM WEBHOOK SLACK DISCORD TEAMS].freeze
    NOTIFICATION_TYPES = %w[
      ALL BACKUP_SUCCESS BACKUP_FAILED HEALTHCHECK_SUCCESS HEALTHCHECK_FAILED
      VERIFICATION_SUCCESS VERIFICATION_FAILED
    ].freeze

    # GET /notifiers
    def list(workspace_id: nil)
      collection(http_get("notifiers", { workspace_id: workspace_id || client.workspace_id! }), key: "notifiers")
    end
    alias all list

    # GET /notifiers/{id}
    def get(id)
      object(http_get("notifiers/#{escape(id)}"))
    end
    alias find get

    # POST /notifiers
    def save(**attributes)
      object(http_post("notifiers", with_default_workspace(attributes)))
    end
    alias create save
    alias update save

    # DELETE /notifiers/{id}
    def delete(id)
      acknowledged(http_delete("notifiers/#{escape(id)}"))
    end

    # POST /notifiers/{id}/test — sends a test notification.
    def test(id)
      acknowledged(http_post("notifiers/#{escape(id)}/test"))
    end

    # POST /notifiers/direct-test — tests a payload that has not been saved yet.
    def direct_test(**attributes)
      acknowledged(http_post("notifiers/direct-test", attributes))
    end

    # POST /notifiers/{id}/transfer
    def transfer(id, target_workspace_id:)
      acknowledged(http_post("notifiers/#{escape(id)}/transfer", { targetWorkspaceId: target_workspace_id }))
    end
  end
end
