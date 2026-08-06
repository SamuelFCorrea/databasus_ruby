## [Unreleased]

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
