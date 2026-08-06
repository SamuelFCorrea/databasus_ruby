# frozen_string_literal: true

module DatabasusRuby
  # Backup destinations.
  #
  #   client.storages.save(name: "offsite", type: "S3",
  #                        workspaceId: id, s3Storage: { ... })
  #
  # POST /storages both creates and updates: include `id` in the payload to
  # update an existing storage.
  class Storages < Object
    include Endpoint

    TYPES = %w[LOCAL S3 GOOGLE_DRIVE NAS AZURE_BLOB FTP SFTP RCLONE].freeze

    # GET /storages
    def list(workspace_id: nil)
      collection(http_get("storages", { workspace_id: workspace_id || client.workspace_id! }), key: "storages")
    end
    alias all list

    # GET /storages/{id}
    def get(id)
      object(http_get("storages/#{escape(id)}"))
    end
    alias find get

    # POST /storages
    def save(**attributes)
      object(http_post("storages", with_default_workspace(attributes)))
    end
    alias create save
    alias update save

    # DELETE /storages/{id}
    def delete(id)
      acknowledged(http_delete("storages/#{escape(id)}"))
    end

    # POST /storages/{id}/test
    def test(id)
      acknowledged(http_post("storages/#{escape(id)}/test"))
    end

    # POST /storages/direct-test — tests a payload that has not been saved yet.
    def direct_test(**attributes)
      acknowledged(http_post("storages/direct-test", attributes))
    end

    # POST /storages/{id}/transfer
    def transfer(id, target_workspace_id:)
      acknowledged(http_post("storages/#{escape(id)}/transfer", { targetWorkspaceId: target_workspace_id }))
    end
  end
end
