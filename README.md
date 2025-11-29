# SgiathAuth

Opinionated authentication library for Phoenix LiveView applications using [WorkOS AuthKit](https://workos.com/docs/user-management).

## Installation

Add `sgiath_auth` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:sgiath_auth, github: "sgiath/auth"}
  ]
end
```

## Configuration

### Required

```elixir
# config/runtime.exs
config :sgiath_auth,
  workos_client_id: System.fetch_env!("WORKOS_CLIENT_ID"),
  workos_secret_key: System.fetch_env!("WORKOS_SECRET_KEY"),
  callback_url: "https://yourapp.com/auth/callback"
```

### Optional

```elixir
config :sgiath_auth,
  # organization to add all new users to, useful when running multiple apps under
  # one WorkOS account and separating users by organizations
  organization_id: "org_...",
  # Path to redirect unauthenticated users (default: "/sign-in")
  sign_in_path: "/login",
  # Path to redirect after sign-in/sign-out (default: "/")
  default_path: "/dashboard",
  # Module implementing SgiathAuth.Profile behaviour (default: nil)
  profile_module: MyApp.Profile
```

## Setup

### 1. Add to your supervision tree

```elixir
# lib/my_app/application.ex
def start(_type, _args) do
  children = [
    # ... other children
    SgiathAuth.Supervisor
  ]

  opts = [strategy: :one_for_one, name: MyApp.Supervisor]
  Supervisor.start_link(children, opts)
end
```

### 2. Configure routes

```elixir
# lib/my_app_web/router.ex
scope "/auth", SgiathAuth do
  pipe_through [:browser]

  get "/sign-in", Controller, :sign_in
  get "/sign-up", Controller, :sign_up
  get "/sign-out", Controller, :sign_out
  get "/callback", Controller, :callback
end
```

### 3. Add plugs to your browser pipeline

```elixir
# lib/my_app_web/router.ex
import SgiathAuth

pipeline :browser do
  # ... existing plugs
  plug :fetch_session
  plug :fetch_current_scope
end
```

### 4. Configure LiveView hooks

```elixir
# lib/my_app_web.ex
def live_view do
  quote do
    use Phoenix.LiveView, layout: {MyAppWeb.Layouts, :app}

    on_mount {SgiathAuth, :mount_current_scope}
    # or for routes requiring authentication:
    # on_mount {SgiathAuth, :require_authenticated}
  end
end
```

### 5. Protect routes

For regular controllers:

```elixir
# lib/my_app_web/router.ex
import SgiathAuth

pipeline :require_authenticated do
  plug :require_authenticated_user
end

scope "/", MyAppWeb do
  pipe_through [:browser, :require_authenticated]

  # Protected routes
end
```

For LiveView, use the `:require_authenticated` hook:

```elixir
live_session :authenticated, on_mount: [{SgiathAuth, :require_authenticated}] do
  live "/dashboard", DashboardLive
end
```

## Profile Module

To populate the `profile` field in `SgiathAuth.Scope` with application-specific data, implement the `SgiathAuth.Profile` behaviour:

```elixir
defmodule MyApp.Profile do
  @behaviour SgiathAuth.Profile

  @impl SgiathAuth.Profile
  def load_profile(%{"id" => user_id}) do
    MyApp.UserProfile
    |> where(user_id: ^user_id)
    |> MyApp.Repo.all()
    |> case do
      [] -> 
        # does not have a profile, create one automatically or return nil to deal with it later
        nil

      [%MyApp.UserProfile{} = profile] ->
        # user have one profile
        profile

      profiles when is_list(profiles) ->
        # user have multiple profiles, either invariant or intended
        nil
    end
  end
end
```

Then configure it:

```elixir
config :sgiath_auth, profile_module: MyApp.Profile
```

The profile will be available in `conn.assigns.current_scope.profile` and `socket.assigns.current_scope.profile`.

## SgiathAuth.Scope

The `SgiathAuth.Scope` struct contains:

- `user` - The WorkOS user map
- `profile` - Application-specific profile data (if `profile_module` is configured)
- `admin` - The admin email when using impersonation (from JWT `act.sub` claim)
