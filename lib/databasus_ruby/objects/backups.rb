# frozen_string_literal: true

module DatabasusRuby
  # Logical backups.
  #
  #   page = client.backups.list(database_id: id, status: "COMPLETED", limit: 20)
  #   page.extras.total_usage_mb          # storage used by all of the database's backups
  #   page.first.raw_database_size_mb     # size of the database when it was dumped
  #
  #   File.open("dump", "wb") { |io| client.backups.download_to(backup.id, io) }
  #
  # A download is a single-use token (POST /download-tokens, valid five
  # minutes) spent on GET /logical-backups/{id}/file. #download_to streams the
  # file; #download reads it into memory and is only fit for small dumps.
  class Backups < Object
    include Endpoint

    STATUSES = %w[IN_PROGRESS COMPLETED FAILED CANCELED].freeze
    VERIFICATION_STATUSES = %w[NOT_VERIFIED VERIFIED_SUCCESSFUL VERIFICATION_FAILED].freeze

    # GET /logical-backups — newest first. `status` takes one value or an array.
    def list(database_id:, status: nil, created_before: nil, limit: nil, after: nil)
      response = http_get("logical-backups", {
                            databaseId: require_id(database_id),
                            status: status,
                            createdBefore: created_before,
                            limit: limit,
                            after: after
                          })
      collection(response)
    end
    alias all list

    # GET /logical-backups/{id}
    def get(id)
      object(http_get("logical-backups/#{escape(id)}"))
    end
    alias find get

    # POST /logical-backups — queues a backup run for the database.
    def create(database_id:)
      object(http_post("logical-backups", { databaseId: require_id(database_id) }))
    end
    alias trigger create

    # DELETE /logical-backups/{id}
    def delete(id)
      acknowledged(http_delete("logical-backups/#{escape(id)}"))
    end

    # POST /logical-backups/{id}/cancel
    def cancel(id)
      object(http_post("logical-backups/#{escape(id)}/cancel"))
    end

    # POST /download-tokens -> { token, fileName, expiresAt }
    def download_token(id)
      object(http_post("download-tokens", { backupId: require_id(id) }))
    end

    # GET /logical-backups/{id}/file — the raw body, in memory.
    def file(id, token:)
      http_get("logical-backups/#{escape(id)}/file", { token: token }).body
    end

    # Mints a token and streams the file into `io`.
    #
    # @return [DatabasusRuby::Object] the token grant (`file_name`, `expires_at`)
    #   plus `bytes`, the number of bytes written
    def download_to(id, io)
      grant = download_token(id)
      bytes = file_to(id, io, token: grant.token)
      Object.new(grant.to_h.except("token").merge("bytes" => bytes))
    end

    # Streams the file into `io` with a token from #download_token. Mint the
    # token first when the caller must fail before it starts answering (an
    # HTTP response whose headers are already sent cannot turn into an error).
    #
    # @return [Integer] bytes written
    def file_to(id, io, token:)
      client.stream("logical-backups/#{escape(id)}/file", io: io, params: { token: token })
    end

    # Mints a token and fetches the file in one call, in memory. Returns
    # [file_name, contents]. Prefer #download_to for real dumps.
    def download(id)
      grant = download_token(id)
      [grant.file_name, file(id, token: grant.token)]
    end
  end
end
