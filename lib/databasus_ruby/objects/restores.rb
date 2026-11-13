# frozen_string_literal: true

module DatabasusRuby
  # Restores of a logical backup into a target database.
  #
  #   target = DatabasusRuby::Restores.postgresql_target(
  #     host: "db.internal", port: 5432, username: "app", password: "secret",
  #     database: "copy_of_prod"
  #   )
  #   restore = client.restores.start(backup_id: backup.id, target: target)
  #   client.restores.get(restore.id).status   # IN_PROGRESS -> COMPLETED | FAILED | CANCELED
  #
  # The target's secrets are used only by the running restore; Databasus does
  # not store them.
  class Restores < Object
    include Endpoint

    STATUSES = %w[IN_PROGRESS COMPLETED FAILED CANCELED].freeze
    SSL_MODES = %w[disable require verify-ca verify-full].freeze

    # Builds a PostgreSQL logical restore target.
    #
    # Ownership and privileges are off by default: restoring them needs the
    # source cluster's roles on the target, and their absence is the usual
    # cause of a restore that loads every row and still fails.
    #
    # @param cpu_count [Integer] parallel pg_restore jobs (Databasus caps it at 8)
    # @param exclude_extensions [Boolean] skip CREATE EXTENSION entries
    # @return [Hash] the `target` body of #start
    def self.postgresql_target(host:, port:, username:, password:, database:, ssl_mode: "disable", cpu_count: 1,
                               exclude_extensions: false, restore_ownership: false, restore_privileges: false,
                               ssh_tunnel: nil)
      {
        type: "POSTGRES_LOGICAL",
        host: host,
        port: port,
        username: username,
        password: password,
        database: database,
        sslMode: ssl_mode,
        sshTunnel: ssh_tunnel || { isEnabled: false },
        cpuCount: cpu_count,
        isExcludeExtensions: exclude_extensions,
        isRestoreOwnership: restore_ownership,
        isRestorePrivileges: restore_privileges
      }
    end

    # GET /restores — the restores of one backup, newest first.
    def list(backup_id:, limit: nil, after: nil)
      collection(http_get("restores", { backupId: require_id(backup_id), limit: limit, after: after }))
    end
    alias all list

    # POST /restores — answers at once with the restore IN_PROGRESS.
    def start(backup_id:, target:)
      object(http_post("restores", { backupId: require_id(backup_id), target: target }))
    end
    alias create start

    # GET /restores/{id}
    def get(id)
      object(http_get("restores/#{escape(id)}"))
    end
    alias find get

    # POST /restores/{id}/cancel
    def cancel(id)
      object(http_post("restores/#{escape(id)}/cancel"))
    end
  end
end
