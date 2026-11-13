# frozen_string_literal: true

module DatabasusRuby
  # Databases under backup.
  #
  #   client.databases.list(workspace_id: id).each { |database| database.name }
  #   client.databases.create(name: "primary", workspaceId: id, notifierIds: [],
  #                           settings: { type: "POSTGRES_LOGICAL", ... })
  #
  # `settings` is the engine-specific half, discriminated by its `type`
  # (POSTGRES_LOGICAL, POSTGRES_PHYSICAL, MYSQL, MARIADB, MONGODB).
  class Databases < Object
    include Endpoint

    TYPES = %w[POSTGRES_LOGICAL POSTGRES_PHYSICAL MYSQL MARIADB MONGODB].freeze

    # GET /databases
    def list(workspace_id: nil, notifier_id: nil, limit: nil, after: nil)
      response = http_get("databases", {
                            workspaceId: workspace_id || client.workspace_id!,
                            notifierId: notifier_id,
                            limit: limit,
                            after: after
                          })
      collection(response, as: Database)
    end
    alias all list

    # Every database of the workspace, following the cursor across pages.
    #
    # @return [Array<DatabasusRuby::Database>]
    def list_all(workspace_id: nil, limit: 100)
      databases = []
      after = nil
      loop do
        page = list(workspace_id: workspace_id, limit: limit, after: after)
        databases.concat(page.data)
        break if page.last_page?

        after = page.next_cursor
      end
      databases
    end

    # GET /databases/{id}
    def get(id)
      object(http_get("databases/#{escape(id)}"), as: Database)
    end
    alias find get

    # POST /databases
    def create(**attributes)
      object(http_post("databases", with_default_workspace(attributes)), as: Database)
    end

    # PUT /databases/{id} — the body is the full DatabaseUpdate payload.
    def update(id, **attributes)
      object(http_put("databases/#{escape(id)}", attributes), as: Database)
    end

    # DELETE /databases/{id}
    def delete(id)
      acknowledged(http_delete("databases/#{escape(id)}"))
    end

    # POST /databases/{id}/copy
    def copy(id)
      object(http_post("databases/#{escape(id)}/copy"), as: Database)
    end

    # POST /databases/{id}/test -> { isConnected, reason, error }
    def test(id)
      object(http_post("databases/#{escape(id)}/test"))
    end

    def connected?(id)
      test(id).is_connected == true
    end

    # The backups of one database by id. A database returned by this endpoint
    # answers the same two methods without the id — see Database.
    def backups(id, **filters)
      client.backups.list(database_id: require_id(id), **filters)
    end

    def backup(id)
      client.backups.create(database_id: require_id(id))
    end
  end
end
