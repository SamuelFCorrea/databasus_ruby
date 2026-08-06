# frozen_string_literal: true

module DatabasusRuby
  # Databases under backup.
  #
  #   client.databases.list(workspace_id: id)
  #   client.databases.create(name: "primary", type: "POSTGRES_LOGICAL",
  #                           workspaceId: id, postgresqlLogical: { ... })
  #
  # The create/update bodies are the full databases.Database payload, whose
  # engine-specific half lives under one of `postgresqlLogical`,
  # `postgresqlPhysical`, `mysql`, `mariadb` or `mongodb`.
  class Databases < Object
    include Endpoint

    TYPES = %w[POSTGRES_LOGICAL POSTGRES_PHYSICAL MYSQL MARIADB MONGODB].freeze
    HEALTH_STATUSES = %w[AVAILABLE UNAVAILABLE].freeze

    # GET /databases
    def list(workspace_id: nil)
      collection(http_get("databases", { workspace_id: workspace_id || client.workspace_id! }),
                 key: "databases", as: Database)
    end
    alias all list

    # GET /databases/{id}
    def get(id)
      object(http_get("databases/#{escape(id)}"), as: Database)
    end
    alias find get

    # POST /databases/create
    def create(**attributes)
      object(http_post("databases/create", with_default_workspace(attributes)), as: Database)
    end

    # POST /databases/update — the id travels in the body, not the path.
    def update(**attributes)
      object(http_post("databases/update", attributes), as: Database)
    end

    # DELETE /databases/{id}
    def delete(id)
      acknowledged(http_delete("databases/#{escape(id)}"))
    end

    # POST /databases/{id}/copy
    def copy(id)
      object(http_post("databases/#{escape(id)}/copy"), as: Database)
    end

    # POST /databases/{id}/test-connection — true when the database answers.
    def test_connection(id)
      acknowledged(http_post("databases/#{escape(id)}/test-connection"))
    end

    # POST /databases/test-connection-direct — tests a payload that has not
    # been saved yet.
    def test_connection_direct(**attributes)
      acknowledged(http_post("databases/test-connection-direct", attributes))
    end

    # POST /databases/create-readonly-user -> { username, password }
    def create_readonly_user(**attributes)
      object(http_post("databases/create-readonly-user", attributes))
    end

    # POST /databases/create-replication-only-user (PostgreSQL physical only)
    def create_replication_only_user(**attributes)
      object(http_post("databases/create-replication-only-user", attributes))
    end

    # POST /databases/is-readonly -> { isReadOnly, privileges }
    def readonly(**attributes)
      object(http_post("databases/is-readonly", attributes))
    end

    def readonly?(**attributes)
      readonly(**attributes).isReadOnly == true
    end

    # The backups of one database by id. A database returned by this endpoint
    # answers the same two methods without the id — see Database.
    #
    #   client.databases.backups(database.id, status: "COMPLETED")
    #   client.databases.backup(database.id)          # queue a run
    #
    # #backups takes the same filters as Backups#list.
    def backups(id, **filters)
      client.backups.list(database_id: require_id(id), **filters)
    end

    def backup(id)
      client.backups.create(database_id: require_id(id))
    end

    # GET /databases/notifier/{id}/databases-count
    def notifier_databases_count(notifier_id)
      single_value(http_get("databases/notifier/#{escape(notifier_id)}/databases-count"))
    end

    # GET /databases/notifier/{id}/is-using
    def notifier_using?(notifier_id)
      single_value(http_get("databases/notifier/#{escape(notifier_id)}/is-using")) == true
    end
  end
end
