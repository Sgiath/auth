# SgiathAuth usage rules (LLM oriented)

This library is a Phoenix LiveView authentication layer around WorkOS AuthKit. It owns the OAuth flow, token validation, session refresh, and a `Scope` struct that merges WorkOS user data with app-specific profile/admin data.

## Core mental model

- `SgiathAuth.Controller` handles sign-in/sign-up/callback/sign-out (+ refresh endpoint)
- `SgiathAuth.fetch_current_scope/2` is the main Plug that validates tokens, loads user/org, and assigns `:current_scope`
- `SgiathAuth.Scope` builds the session scope (`user`, `org`, `profile`, `admin`, `role`)
- `SgiathAuth.Token` validates access tokens using WorkOS JWKS
- `SgiathAuth.Supervisor` runs the JWKS strategy refresher

## Required configuration

Add these values (usually `config/runtime.exs`):

```elixir
config :sgiath_auth,
  workos_client_id: System.fetch_env!("WORKOS_CLIENT_ID"),
  workos_secret_key: System.fetch_env!("WORKOS_SECRET_KEY"),
  callback_url: "https://yourapp.com/auth/callback"
```

## Optional configuration (align routes)

```elixir
config :sgiath_auth,
  sign_in_path: "/auth/sign-in",   # default: "/sign-in"
  refresh_path: "/auth/refresh",   # default: "/auth/refresh"
  default_path: "/",               # default: "/"
  logout_return_to: "/",            # default: "/"
  profile_module: MyApp.Profile,    # default: nil
  auto_create_organization: false   # default: false
```

If you scope auth routes under `/auth`, set `sign_in_path` to `/auth/sign-in`. The LiveView hook uses `sign_in_path`/`refresh_path` directly, so mismatched paths cause redirects to non-existent routes.

## Supervision

Start `SgiathAuth.Supervisor` so JWKS refresh works:

```elixir
children = [
  SgiathAuth.Supervisor
]
```

## Router wiring

Minimal route set (include refresh):

```elixir
scope "/auth", SgiathAuth do
  pipe_through [:browser]

  get "/sign-in", Controller, :sign_in
  get "/sign-up", Controller, :sign_up
  get "/sign-out", Controller, :sign_out
  get "/callback", Controller, :callback
  get "/refresh", Controller, :refresh
end
```

## Plugs and LiveView hooks

- Controller pipeline: ensure `plug :fetch_session` runs before `plug :fetch_current_scope`.
- Protect controllers with `plug :require_authenticated_user`.
- LiveView hooks:
  - `on_mount {SgiathAuth, :mount_current_scope}` loads `current_scope` if tokens exist.
  - `on_mount {SgiathAuth, :require_authenticated}` guards and redirects.
  - `on_mount {SgiathAuth, :test_authenticated}` exists only in `Mix.env() == :test`.

## Flow details (what actually happens)

1. `Controller.sign_in/sign_up` builds WorkOS authorization URL, storing return-to path in state.
2. `Controller.callback` exchanges the auth code for tokens and stores:
   - `:access_token`
   - `:refresh_token`
   - `:org_id` (from WorkOS response)
3. `fetch_current_scope`:
   - Verifies access token (requires `sub`, `role`, `sid` claims).
   - Loads WorkOS user via `WorkOS.get_user/1`.
   - Builds scope: `Scope.for_user(user, role)` loads `profile` + optional `admin`.
   - Loads org via session `:org_id` (optional auto-create).
   - Assigns `conn.assigns.current_scope` and sets session `:live_socket_id`.
4. If token verification fails, it refreshes once with `refresh_token`. On refresh failure it clears the session.
5. LiveView `:require_authenticated`:
   - If scope present, continues.
   - If access token exists but invalid, redirects to `refresh_path`.
   - If no token, redirects to `sign_in_path`.

## Session keys used

- `:access_token` / `:refresh_token` - WorkOS tokens
- `:org_id` - WorkOS organization id
- `:live_socket_id` - from JWT `sid`
- `:user_return_to` - set by `require_authenticated_user` on GET requests

## Organization behavior

- `fetch_current_scope` tries to load `org_id` from session.
- If missing/invalid and `auto_create_organization` is true:
  - creates org named `"<first_name> <last_name>"`
  - creates membership for user
  - writes `org_id` to session
- Otherwise `scope.org` is `nil`.

## Profile and admin loading

- Configure `:profile_module` implementing `SgiathAuth.Profile`.
- `load_profile/1` populates `scope.profile`.
- `load_admin/1` is optional; when present populates `scope.admin`.
- If module missing or callback not defined, `profile/admin` stay `nil`.

## Token verification

- `SgiathAuth.Token` uses Joken with JWKS strategy.
- Issuer is `https://api.workos.com/user_management/<client_id>`.
- JWKS URL is `https://api.workos.com/sso/jwks/<client_id>`.
- JWKS refresher runs under `SgiathAuth.Supervisor` every 2 seconds.

## WorkOS API wrappers

These modules wrap WorkOS HTTP APIs using `Req` and return `{:ok, body}` or `{:error, reason}` (204 returns `:ok`). All error paths are logged.

- `SgiathAuth.WorkOS` - OAuth URLs, auth code exchange, token refresh, basic user fetch.
- `SgiathAuth.WorkOS.User` - CRUD + list; functions expect full IDs like `"user_..."`.
- `SgiathAuth.WorkOS.Organization` - CRUD + list; functions expect full IDs like `"org_..."`.
- `SgiathAuth.WorkOS.OrganizationMembership` - list/create; expects `"user_..."` and `"org_..."`.
- `SgiathAuth.WorkOS.ApiKeys` - list/create/delete/validate; expects prefixed IDs.

Note: `Organization.create/2` currently pattern-matches `"org_" <> name` and sends `name` without the prefix. Callers must pass a string starting with `"org_"` or adjust the implementation if you change this API.

## Safe changes / agent guidance

- If you change auth routes, update `sign_in_path` and `refresh_path` config.
- If you change token claims or issuer, update both `SgiathAuth.Token` and any callers that pattern-match `sub/role/sid`.
- If you modify session keys, update `Controller`, `fetch_current_scope/2`, and LiveView hooks together.
- Keep `validate_relative_path/2` logic intact to avoid open-redirects.
- PostHog is optional; `fetch_current_scope` sets context only when module is loaded.
