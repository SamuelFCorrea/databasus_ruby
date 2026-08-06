# frozen_string_literal: true

require "faraday"

require_relative "databasus_ruby/version"

# Ruby client for the Databasus backup-management API.
#
#   client = DatabasusRuby::Client.new(api_key: ENV["DATABASUS_API_KEY"],
#                                     url: "https://databasus.example.com/api/v1/")
#   client.databases.list(workspace_id: workspace_id)
#
# See DatabasusRuby::Client for how the endpoint domains hang off the client.
module DatabasusRuby
  autoload :Client, "databasus_ruby/client"
  autoload :Collection, "databasus_ruby/collection"
  autoload :Endpoint, "databasus_ruby/endpoint"
  autoload :Object, "databasus_ruby/object"
  autoload :Record, "databasus_ruby/record"

  autoload :Error, "databasus_ruby/error"
  autoload :ConfigurationError, "databasus_ruby/error"
  autoload :APIError, "databasus_ruby/error"
  autoload :BadRequestError, "databasus_ruby/error"
  autoload :AuthenticationError, "databasus_ruby/error"
  autoload :ForbiddenError, "databasus_ruby/error"
  autoload :NotFoundError, "databasus_ruby/error"
  autoload :ConflictError, "databasus_ruby/error"
  autoload :RateLimitError, "databasus_ruby/error"
  autoload :ServerError, "databasus_ruby/error"

  autoload :Auth, "databasus_ruby/objects/auth"
  autoload :Backups, "databasus_ruby/objects/backups"
  autoload :Databases, "databasus_ruby/objects/databases"
  autoload :Notifiers, "databasus_ruby/objects/notifiers"
  autoload :Storages, "databasus_ruby/objects/storages"
  autoload :Users, "databasus_ruby/objects/users"
  autoload :Workspaces, "databasus_ruby/objects/workspaces"

  autoload :Database, "databasus_ruby/records/database"
end
