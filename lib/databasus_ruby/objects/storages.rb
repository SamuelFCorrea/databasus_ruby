# frozen_string_literal: true

module DatabasusRuby
  # Backup destinations.
  #
  #   client.storages.create(workspaceId: id, name: "offsite", settings: { type: "S3", ... })
  #   client.storages.backup_usage(storage.id)
  class Storages < Object
    include Endpoint

    TYPES = %w[LOCAL S3 GOOGLE_DRIVE NAS AZURE_BLOB FTP SFTP RCLONE].freeze

    # GET /storages
    def list(workspace_id: nil, limit: nil, after: nil)
      collection(http_get("storages",
                          { workspaceId: workspace_id || client.workspace_id!, limit: limit, after: after }))
    end
    alias all list

    # GET /storages/{id}
    def get(id)
      object(http_get("storages/#{escape(id)}"))
    end
    alias find get

    # POST /storages — `workspaceId`, `name` and the type-specific `settings`.
    def create(**attributes)
      object(http_post("storages", with_default_workspace(attributes)))
    end

    # PUT /storages/{id} — `name` and `settings`.
    def update(id, **attributes)
      object(http_put("storages/#{escape(id)}", attributes))
    end

    # DELETE /storages/{id}
    def delete(id)
      acknowledged(http_delete("storages/#{escape(id)}"))
    end

    # GET /storages/{id}/backup-usage — the catalog-recorded usage of the storage.
    def backup_usage(id)
      object(http_get("storages/#{escape(id)}/backup-usage"))
    end

    # POST /storages/{id}/test
    def test(id)
      object(http_post("storages/#{escape(id)}/test"))
    end

    # POST /storages/{id}/transfer
    def transfer(id, target_workspace_id:)
      object(http_post("storages/#{escape(id)}/transfer", { targetWorkspaceId: target_workspace_id }))
    end
  end
end
