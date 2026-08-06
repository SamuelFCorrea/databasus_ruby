# DatabasusRuby

A Ruby client for the [Databasus](https://github.com/SamuelFCorrea/databasus_ruby) backup-management API.

Each API domain is an endpoint object hanging off the client, list endpoints all
return a `Collection`, and every response is a duck-typed `Object` you can read
with plain method calls.

## Installation

Install the gem and add to the application's Gemfile by executing:

```bash
bundle add databasus_ruby
```

If bundler is not being used to manage dependencies, install the gem by executing:

```bash
gem install databasus_ruby
```

## Usage

### Authentication

Databasus authenticates with a bearer token. For everything except the
verification-agent endpoints that token is a user JWT, which you get by signing
in:

```ruby
client = DatabasusRuby::Client.new(url: "https://databasus.example.com/api/v1/")

client.auth.signin(email: "you@example.com", password: ENV["DATABASUS_PASSWORD"])
client.users.me.email  # => "you@example.com"
```

`signin` installs the returned token on the client. If you already have a
token, pass it as `api_key` instead:

```ruby
client = DatabasusRuby::Client.new(
  api_key: ENV["DATABASUS_API_KEY"],
  url: ENV.fetch("DATABASUS_URL"),
  workspace_id: ENV["DATABASUS_WORKSPACE_ID"] # optional default, see below
)
```

`#signup` registers and installs the token the same way; both raise
`DatabasusRuby::Error` if the response carries no token, and the result still
exposes it as `result.token` if you want to keep it. OAuth code exchange lives
at `client.auth.github_callback` and `client.auth.google_callback`.

### Workspaces

Almost everything in Databasus is scoped to a workspace.

```ruby
client.workspaces.list.each { |workspace| puts workspace.name }

workspace = client.workspaces.create(name: "production")
client.workspaces.add_member(workspace.id, email: "ops@example.com", role: "WORKSPACE_ADMIN")
client.workspaces.members(workspace.id).map(&:email)
client.workspaces.audit_logs(workspace.id, limit: 50)
```

Because the workspace-scoped list endpoints all require a workspace id, you can
set one default on the client and omit it per call:

```ruby
client.workspace_id = workspace.id
client.databases.list   # no argument needed
client.storages.list
client.notifiers.list
```
### Databases

```ruby
databases = client.databases.list(workspace_id: workspace.id)
databases.total
databases.first.name

database = client.databases.create(
  name: "primary",
  type: "POSTGRES_LOGICAL",           # DatabasusRuby::Databases::TYPES
  workspaceId: workspace.id,
  postgresqlLogical: {
    host: "10.0.0.1",
    port: 5432,
    username: "backup",
    password: ENV["PG_PASSWORD"],
    database: "app_production",
    version: "17",
    sslMode: "require"
  }
)

database.name
database.postgresqlLogical.host
database.workspace_id                 # snake_case reads camelCase keys too

client.databases.test_connection(database.id)      # => true, or raises
client.databases.update(id: database.id, name: "primary-eu")
client.databases.copy(database.id)
client.databases.delete(database.id)
```

A database can reach its own backups, which delegates to the `backups` endpoint
with the same filters as `client.backups.list`:

```ruby
client.databases.backups(database.id, status: "COMPLETED", limit: 25)
client.databases.backup(database.id)               # queue a run
```

`update` posts to `/databases/update` with the id in the body, matching the API.
There is also `test_connection_direct`, `create_readonly_user`,
`create_replication_only_user` and `readonly?` for a payload you have not saved
yet.

### Backups

```ruby
backups = client.backups.list(
  database_id: database.id,
  status: %w[COMPLETED FAILED],       # DatabasusRuby::Backups::STATUSES
  limit: 25
)

backups.total        # => 137
backups.next_offset  # => 25
backups.first.fileName

client.backups.create(database_id: database.id)   # queue a run
client.backups.cancel(backup.id)
client.backups.delete(backup.id)

filename, contents = client.backups.download(backup.id)
File.binwrite(filename, contents)
```

`#download` mints a short-lived token and streams the file in one step; use
`#download_token` and `#file` if you need the two halves separately.

### Storages and notifiers

Both use a single save endpoint for create and update — include `id` in the
payload to update.

```ruby
storage = client.storages.save(
  name: "offsite",
  type: "S3",                          # DatabasusRuby::Storages::TYPES
  workspaceId: workspace.id,
  s3Storage: { bucket: "backups", region: "eu-west-1", accessKeyId: "...", secretAccessKey: "..." }
)
client.storages.test(storage.id)
client.storages.transfer(storage.id, target_workspace_id: other.id)

notifier = client.notifiers.save(
  name: "ops",
  notifierType: "SLACK",               # DatabasusRuby::Notifiers::TYPES
  workspaceId: workspace.id,
  slackNotifier: { token: "...", channelId: "C123" }
)
client.notifiers.test(notifier.id)
```

`direct_test` on either domain tests an unsaved payload.

### Users

`client.users` covers both the signed-in user and instance-wide administration
(the latter needs an `ADMIN` token):

```ruby
client.users.me.name
client.users.update_me(name: "New Name")
client.users.change_password(new_password: ENV["NEW_PASSWORD"])
client.users.invite(email: "new@example.com", intended_workspace_id: workspace.id,
                   intended_workspace_role: "WORKSPACE_MEMBER")

client.users.list(query: "ops", limit: 25)   # ADMIN
client.users.deactivate(user_id)             # ADMIN
client.users.change_role(user_id, role: "ADMIN")
client.users.settings                        # instance registration settings
```

### Collections

Every list endpoint returns a `DatabasusRuby::Collection`, regardless of which
of the API's three list shapes the endpoint uses:

```ruby
backups = client.backups.list(database_id: database.id, limit: 25)

backups.each { |backup| ... }        # Enumerable
backups.map(&:status)
backups.size                         # items on this page
backups.total                        # items overall
backups.limit                        # nil when the endpoint does not paginate
backups.offset
backups.paginated?
backups.next_offset                  # nil on the last page
backups.last_page?
backups.data                         # the underlying Array
```

Paging through everything:

```ruby
offset = 0
loop do
  page = client.backups.list(database_id: database.id, limit: 100, offset: offset)
  page.each { |backup| process(backup) }
  break if page.last_page?

  offset = page.next_offset
end
```

### Response objects

Responses are wrapped in `DatabasusRuby::Object`, which reads keys as methods,
wraps nested hashes and arrays as it goes, and accepts snake_case for the API's
camelCase keys:

```ruby
database.postgresqlLogical.sslMode
database.postgresql_logical.ssl_mode   # the same thing
database.notifiers.map(&:name)         # arrays of objects are wrapped too
database.to_h                          # the raw decoded payload
database["name"]
database.key?(:workspace_id)
```

Databasus omits empty fields, so reading a key that isn't in the payload
returns `nil` rather than raising.

### Errors

Non-2xx responses raise a subclass of `DatabasusRuby::APIError` carrying the
status and decoded body:

| Status | Error |
| --- | --- |
| 400 | `DatabasusRuby::BadRequestError` |
| 401 | `DatabasusRuby::AuthenticationError` |
| 403 | `DatabasusRuby::ForbiddenError` |
| 404 | `DatabasusRuby::NotFoundError` |
| 409 | `DatabasusRuby::ConflictError` |
| 429 | `DatabasusRuby::RateLimitError` |
| 5xx | `DatabasusRuby::ServerError` |

```ruby
begin
  client.databases.test_connection(database.id)
rescue DatabasusRuby::BadRequestError => e
  e.message   # => "dial tcp 10.0.0.1:5432: connect: connection refused"
  e.status    # => 400
  e.body      # => { "error" => "dial tcp ..." }
end
```

`DatabasusRuby::ConfigurationError` (a sibling of `APIError` under
`DatabasusRuby::Error`) is raised before any request goes out when the client is
missing something it needs, such as a workspace id.

## API coverage

Implemented: `auth`, `users` (including user management and instance settings),
`workspaces` (including membership and audit logs), `databases`, `backups`
(logical), `storages`, `notifiers`.

Not yet wrapped: physical backups and their configs, logical backup configs,
restores, verifications and verification agents/configs, healthchecks, disk
usage, global audit logs and the `system/*` endpoints. The client is ready for
them — each is a new class in `lib/databasus_ruby/objects/` plus an accessor on
`Client`.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run
`rake spec` to run the tests, or `rake` to run the tests and RuboCop. You can
also run `bin/console` for an interactive prompt with a preconfigured `client`.

The specs stub HTTP with WebMock, so they need no running Databasus instance.

To install this gem onto your local machine, run `bundle exec rake install`. To
release a new version, update the version number in `version.rb`, and then run
`bundle exec rake release`, which will create a git tag for the version, push
git commits and the created tag, and push the `.gem` file to
[rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/SamuelFCorrea/databasus_ruby. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/SamuelFCorrea/databasus_ruby/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the DatabasusRuby project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/SamuelFCorrea/databasus_ruby/blob/main/CODE_OF_CONDUCT.md).
