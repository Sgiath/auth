# Sgiath Auth guide

## Project Overview

SgiathAuth is an opinionated authentication library for Phoenix LiveView applications using WorkOS AuthKit. It provides session/JWT-based authentication with refresh token support and first-class LiveView integration via `on_mount` hooks.

## Commands

```bash
mix test              # Run tests
mix format            # Format code
mix compile           # Compile
mix deps.get          # Install dependencies
```

## Architecture

### Core Modules

- **`SgiathAuth`** - Main module with Plug.Conn operations and LiveView hooks
- **`SgiathAuth.Scope`** - Struct representing authenticated user context (user, profile, admin, role)
- **`SgiathAuth.Profile`** - Behavior for app-specific profile loading (optional)
- **`SgiathAuth.Token`** - JWT configuration and validation using Joken
- **`SgiathAuth.Token.Strategy`** - JWKS token strategy for WorkOS token validation
- **`SgiathAuth.WorkOS`** - HTTP client for WorkOS API communication
- **`SgiathAuth.WorkOS.OrganizationMembership`** - Org membership CRUD: `list`, `create`, `get`, `update`, `delete`, `deactivate`, `reactivate`
- **`SgiathAuth.WorkOS.Invitation`** - Invitation management: `list`, `get`, `get_by_token`, `send`, `resend`, `revoke`
- **`SgiathAuth.Controller`** - Phoenix controller with sign-in/sign-up/callback/sign-out endpoints

### Authentication Flow

1. `Controller.sign_in/sign_up` redirects to WorkOS authorize URL
2. WorkOS authenticates user and redirects to callback
3. `Controller.callback` exchanges auth code for tokens via `WorkOS.authenticate_with_code`
4. Tokens stored in session
5. `fetch_current_scope` plug verifies JWT and builds `Scope` struct
6. Token refresh handled automatically via `refresh_session/1`

### Key Patterns

**Plug Middleware**: `fetch_current_scope/2` and `require_authenticated_user/2` for controller routes

**LiveView Hooks**:
- `on_mount(:mount_current_scope)` - Loads user context
- `on_mount(:require_authenticated)` - Guards with redirect
- `on_mount(:test_authenticated)` - Test mode hook (Mix.env == :test)

**Behavior-Based Customization**: `SgiathAuth.Profile` behavior allows apps to implement custom user/profile loading with optional `load_admin/1` callback for impersonation

**Token Validation**: Uses `JokenJwks.DefaultStrategyTemplate` with supervisor-managed periodic JWKS refresh

**Configuration**: Runtime config via `Application.get_env/3` with required keys fetched using `Application.fetch_env!/2`

## Configuration Keys

Required: `workos_client_id`, `workos_secret_key`, `callback_url`

Optional: `sign_in_path` (default: "/sign-in"), `default_path` (default: "/"), `profile_module`, `no_organization_redirect` (required if using `require_organization` plug/hook)

## Development Environment

Uses Nix flakes (`flake.nix`) with direnv for reproducible development (Erlang 28, Elixir 1.19).
