# SgiathAuth

Opinionated authentication for Phoenix LiveView using WorkOS AuthKit.

## Install

```elixir
def deps do
  [
    {:sgiath_auth, github: "sgiath/auth"}
  ]
end
```

## Configure

```elixir
# config/runtime.exs
config :sgiath_auth,
  workos_client_id: System.fetch_env!("WORKOS_CLIENT_ID"),
  workos_secret_key: System.fetch_env!("WORKOS_SECRET_KEY"),
  callback_url: "https://yourapp.com/auth/callback"
```

## Quick setup

```elixir
# lib/my_app/application.ex
children = [
  SgiathAuth.Supervisor
]
```

```elixir
# lib/my_app_web/router.ex
scope "/auth", SgiathAuth do
  pipe_through [:browser]

  get "/sign-in", Controller, :sign_in
  get "/sign-up", Controller, :sign_up
  get "/sign-out", Controller, :sign_out
  get "/callback", Controller, :callback
  get "/refresh", Controller, :refresh
end

import SgiathAuth

pipeline :browser do
  plug :fetch_session
  plug :fetch_current_scope
end

pipeline :require_authenticated do
  plug :require_authenticated_user
end
```

```elixir
# lib/my_app_web.ex
def live_view do
  quote do
    use Phoenix.LiveView, layout: {MyAppWeb.Layouts, :app}

    on_mount {SgiathAuth, :mount_current_scope}
    # or: on_mount {SgiathAuth, :require_authenticated}
  end
end
```

## Profile module (optional)

Implement `SgiathAuth.Profile` to load app-specific profile/admin data, then set:

```elixir
config :sgiath_auth, profile_module: MyApp.Profile
```

## More detail

See `usage-rules.md` for flow, hooks, and behavior notes.
