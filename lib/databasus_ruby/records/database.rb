# frozen_string_literal: true

module DatabasusRuby
  # One database, as returned by the Databases endpoint.
  #
  #   database = client.databases.get(id)
  #   database.backups(status: "COMPLETED")
  #   database.backup                       # queue a run
  #
  # Both delegate to the Backups endpoint, which owns the requests.
  class Database < Record
    # Takes the same filters as Backups#list.
    def backups(**filters)
      client.backups.list(database_id: id!, **filters)
    end

    def backup
      client.backups.create(database_id: id!)
    end
  end
end
