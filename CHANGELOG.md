## [Unreleased]

## [0.2.0] - 2026-11-13

Targets the REST API of Databasus 3.65 and later. Databasus 3.65 replaced its
API (new paths, cursor pagination, RFC 9457 problem responses), so this release
does not talk to 3.64 or earlier: pin `~> 0.1.0` for those.

### Added

- `Restores` endpoint (`start`, `get`, `list`, `cancel`) and
  `Restores.postgresql_target`, which restores without ownership and
  privileges by default.
- `Backups#download_to(id, io)` and `Client#stream`: backups stream to an IO
  instead of being read into memory.
- `Backups#get`; `Databases#list_all`, which follows the cursor; `Databases#test`
  / `#connected?`; `Storages#backup_usage`; `Auth#verify_sign_in_code`.
- `APIError#code` (the problem's `code`); validation field errors are appended
  to the message.
- `SignInCodeRequiredError`, raised by `Auth#signin` when the account needs an
  emailed sign-in code.
- `Collection#next_cursor`, `#last_page?` and `#extras` (page-level fields such
  as the backups page's `totalUsageMb`).

### Changed

- Every path follows the 3.65 API: `POST /sessions`, `/logical-backups`,
  `POST /download-tokens`, `PUT /databases/{id}`, `/workspace-members`,
  `/audit-events`, `/instance-settings`, `/password-resets`.
- List methods take `limit:` / `after:` instead of `limit:` / `offset:`.
- Array query parameters repeat the key (`status=A&status=B`).
- `Notifiers` and `Storages` split `save` into `create` and `update(id, ...)`.

### Removed

- Offset pagination (`Collection#total`, `#limit`, `#offset`, `#next_offset`).
- Endpoints the API dropped: OAuth callbacks, `users/me`, readonly and
  replication users, `test-connection-direct`, notifier usage counts,
  `direct-test`.

## [0.1.0]

### Added

- `DatabasusRuby::Client` with bearer authentication, an optional default
  `workspace_id`, an optional `agent_id`, and one memoized endpoint object per
  API domain.
- Endpoint coverage for `auth`, `users` (profile, administration, instance
  settings), `workspaces` (settings, membership, audit logs), `databases`,
  logical `backups`, `storages` and `notifiers`.
- `DatabasusRuby::Collection`, a uniform `Enumerable` return value for every
  list endpoint, normalizing the API's bare-array, paginated-envelope and
  unpaginated-envelope shapes and exposing `total` / `limit` / `offset` /
  `next_offset`.
- `DatabasusRuby::Object` payload wrapper: nested hashes and arrays are wrapped
  on access, snake_case reads camelCase keys, and omitted fields read as `nil`.
- Error hierarchy under `DatabasusRuby::Error`: `APIError` and its per-status
  subclasses carry the status and decoded body; `ConfigurationError` is raised
  before a request when the client is missing a required value.
- `Databases#backups` and `Databases#backup`, listing and queueing the backups
  of one database by delegating to the `backups` endpoint.
- RBS signatures for the full public API.

## [0.0.1] - 2026-08-04

- Initial release
