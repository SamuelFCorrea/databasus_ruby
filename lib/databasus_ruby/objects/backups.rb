# frozen_string_literal: true

module DatabasusRuby
  # Logical backups.
  #
  #   backups = client.backups.list(database_id: id, status: %w[COMPLETED FAILED])
  #   backups.total
  #   backups.first.fileName
  #
  # Downloads are a two-step flow: mint a short-lived token, then stream the
  # file with it. #download does both.
  class Backups < Object
    include Endpoint

    STATUSES = %w[IN_PROGRESS COMPLETED FAILED CANCELED].freeze
    ENCRYPTIONS = %w[NONE ENCRYPTED].freeze
    VERIFICATION_STATUSES = %w[NOT_VERIFIED VERIFIED_SUCCESSFUL VERIFICATION_FAILED].freeze

    # GET /backups — `status` accepts a single value or an array.
    def list(database_id:, limit: nil, offset: nil, status: nil, before_date: nil, pg_wal_backup_type: nil)
      response = http_get("backups", {
                            database_id: database_id,
                            limit: limit,
                            offset: offset,
                            status: status,
                            beforeDate: before_date,
                            pgWalBackupType: pg_wal_backup_type
                          })
      collection(response, key: "backups")
    end
    alias all list

    # POST /backups — queues a backup run for the database.
    def create(database_id:)
      object(http_post("backups", { database_id: database_id }))
    end
    alias trigger create

    # DELETE /backups/{id}
    def delete(id)
      acknowledged(http_delete("backups/#{escape(id)}"))
    end

    # POST /backups/{id}/cancel
    def cancel(id)
      acknowledged(http_post("backups/#{escape(id)}/cancel"))
    end

    # POST /backups/{id}/download-token -> { token, filename, backupId }
    def download_token(id)
      object(http_post("backups/#{escape(id)}/download-token"))
    end

    # GET /backups/{id}/file — returns the raw body; pass a token from
    # #download_token.
    def file(id, token:)
      http_get("backups/#{escape(id)}/file", { token: token }).body
    end

    # Mints a token and fetches the file in one call. Returns
    # [filename, contents].
    def download(id)
      grant = download_token(id)
      [grant.filename, file(id, token: grant.token)]
    end
  end
end
