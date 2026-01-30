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
  post "/refresh", Controller, :refresh
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

## Refreshing sessions (GET/POST)

The refresh endpoint accepts GET or POST and supports optional `organization_id` for org switching.
Use `return_to` to send users back to their current page after refresh.

```elixir
# In a HEEx template
<form method="post" action="/auth/refresh">
  <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
  <input type="hidden" name="return_to" value={@return_to} />
  <input type="hidden" name="organization_id" value={@organization_id} />
  <button type="submit">Switch org</button>
</form>
```

For LiveView, trigger a full HTTP POST via a client hook (recommended):

```javascript
// assets/js/app.js
let Hooks = {};

Hooks.AuthRefresh = {
  mounted() {
    this.handleEvent("auth:refresh", ({ return_to, organization_id }) => {
      const form = document.createElement("form");
      form.method = "post";
      form.action = "/auth/refresh";

      form.appendChild(this.input("_csrf_token", this.csrfToken()));
      form.appendChild(this.input("return_to", return_to));
      if (organization_id)
        form.appendChild(this.input("organization_id", organization_id));

      document.body.appendChild(form);
      form.submit();
    });
  },
  input(name, value) {
    const input = document.createElement("input");
    input.type = "hidden";
    input.name = name;
    input.value = value;
    return input;
  },
  csrfToken() {
    const meta = document.querySelector("meta[name='csrf-token']");
    return meta ? meta.getAttribute("content") : "";
  },
};
```

```elixir
# In your LiveView
push_event(socket, "auth:refresh", %{return_to: "/dashboard", organization_id: @organization_id})
```

## Profile module (optional)

Implement `SgiathAuth.Profile` to load app-specific profile/admin data, then set:

```elixir
config :sgiath_auth, profile_module: MyApp.Profile
```

## More detail

See `usage-rules.md` for flow, hooks, and behavior notes.
