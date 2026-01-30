defmodule SgiathAuth do
  @moduledoc """
  Authentication and authorization for Phoenix applications using WorkOS AuthKit.

  This module provides:

  - **Plugs** for protecting controller routes
  - **LiveView hooks** for protecting LiveView pages
  - **Session management** with automatic token refresh

  ## Setup

  Add to your router:

      pipeline :browser do
        plug :fetch_session
        plug :fetch_current_scope
      end

      pipeline :authenticated do
        plug :require_authenticated_user
      end

  Add to your LiveView module:

      use MyAppWeb, :live_view

      on_mount {SgiathAuth, :require_authenticated}

  ## Configuration

  Required in `config.exs`:

      config :sgiath_auth,
        workos_client_id: "client_...",
        workos_secret_key: "sk_...",
        callback_url: "https://app.example.com/auth/callback",
        no_organization_redirect: "/select-organization"

  Optional:

      config :sgiath_auth,
        sign_in_path: "/sign-in",        # default: "/sign-in"
        default_path: "/",               # default: "/"
        profile_module: MyApp.Profile    # implements SgiathAuth.Profile behaviour

  ## Authorization Levels

  The plugs and hooks form a hierarchy of access control:

  | Level | Plug | Hook | Checks |
  |-------|------|------|--------|
  | Authenticated | `require_authenticated_user/2` | `:require_authenticated` | `scope.user` present |
  | Organization | `require_organization/2` | `:require_organization` | `scope.org` present |
  | Admin | `require_admin/2` | `:require_admin` | `scope.admin` present |
  """

  import Plug.Conn
  import Phoenix.Controller

  alias SgiathAuth.WorkOS.Organization

  require Logger

  @no_org_redirect Application.compile_env!(:sgiath_auth, :no_organization_redirect)

  # Session Management
  # ==========================================================

  @doc """
  Refreshes the session tokens using the refresh token stored in the session.

  Returns the conn with updated tokens on success, or clears the session on failure.

  ## Options

  - `:organization_id` - switch organization context during refresh

  ## Examples

      # Simple refresh
      conn = refresh_session(conn)

      # Switch organization during refresh
      conn = refresh_session(conn, %{organization_id: "org_123"})
  """
  def refresh_session(conn, params \\ %{}) do
    refresh_token = get_session(conn, :refresh_token)
    refresh_params = refresh_params(params)

    case SgiathAuth.WorkOS.authenticate_with_refresh_token(conn, refresh_token, refresh_params) do
      {:ok, response} ->
        Logger.debug("[auth] refreshed session successfully")

        conn
        |> put_session(:access_token, response["access_token"])
        |> put_session(:refresh_token, response["refresh_token"])
        |> maybe_put_org_id(response)

      {:error, reason} ->
        Logger.debug("[auth] failed to refresh session, reason: #{inspect(reason)}")

        delete_csrf_token()

        conn
        |> configure_session(renew: true)
        |> clear_session()
    end
  end

  # Plugs
  # ==========================================================

  @doc """
  Fetches the current user scope from the session and assigns it to the connection.

  This plug validates the access token, loads the user from WorkOS, and builds
  a `SgiathAuth.Scope` struct. If the token is expired, it attempts a refresh.

  Assigns `:current_scope` to the connection (may be `nil` if not authenticated).

  ## Usage

      plug :fetch_current_scope

  This plug should run early in your pipeline, before any authorization plugs.
  """
  def fetch_current_scope(conn, opts) do
    Logger.debug("[auth] fetching current scope")

    with {:session, %{"access_token" => access_token, "refresh_token" => refresh_token}} <-
           {:session, get_session(conn)},
         {:scope, {:ok, scope, session_id}} <-
           {:scope, build_scope_from_token(access_token)} do
      org_id = get_session(conn, :org_id)
      {conn, org} = ensure_organization(conn, org_id, scope.user)
      scope = %{scope | org: org}

      set_context(%{
        user_id: scope.user["id"],
        profile_id: get_in(scope.profile.id),
        session_id: session_id
      })

      conn
      |> put_session(:access_token, access_token)
      |> put_session(:refresh_token, refresh_token)
      |> put_session(:org_id, org_id)
      |> put_session(:live_socket_id, session_id)
      |> assign(:current_scope, scope)
    else
      {:session, %{}} ->
        Logger.debug("[auth] session without access token")
        assign(conn, :current_scope, nil)

      {:scope, {:error, _reason}} ->
        # Prevent infinite recursion - only attempt refresh once
        if conn.private[:auth_refresh_attempted] do
          Logger.debug("[auth] refresh already attempted, giving up")
          assign(conn, :current_scope, nil)
        else
          Logger.debug("[auth] refreshing session")

          conn
          |> put_private(:auth_refresh_attempted, true)
          |> refresh_session()
          |> fetch_current_scope(opts)
        end
    end
  end

  @doc """
  Requires an authenticated user with a valid scope.

  Redirects to the sign-in page if the user is not authenticated.
  Stores the current path for redirect after successful authentication.

  ## Usage

      plug :require_authenticated_user
  """
  def require_authenticated_user(conn, _opts) do
    if conn.assigns.current_scope && conn.assigns.current_scope.user do
      conn
    else
      conn
      |> maybe_store_return_to()
      |> redirect(to: SgiathAuth.WorkOS.sign_in_path())
      |> halt()
    end
  end

  @doc """
  Requires the user to have an organization selected.

  Behavior:
  - No scope → redirects to sign-in
  - No organization → redirects to `no_organization_redirect` config path
  - Has organization → continues

  ## Usage

      plug :require_organization

  Requires `:no_organization_redirect` to be configured.
  """
  def require_organization(conn, _opts) do
    scope = conn.assigns[:current_scope]

    cond do
      is_nil(scope) ->
        conn
        |> maybe_store_return_to()
        |> redirect(to: SgiathAuth.WorkOS.sign_in_path())
        |> halt()

      is_nil(scope.org) ->
        return_to = current_path(conn)

        conn
        |> redirect(to: "#{@no_org_redirect}?return_to=#{return_to}")
        |> halt()

      :logged_in_with_org ->
        conn
    end
  end

  @doc """
  Requires the user to be an admin (dev team member).

  Behavior:
  - No scope → redirects to sign-in
  - Not admin (`scope.admin` is nil) → redirects to `/`
  - Is admin → continues

  Admin status is determined by the `load_admin/1` callback in your profile module.
  See `SgiathAuth.Profile` for details.

  ## Usage

      plug :require_admin
  """
  def require_admin(conn, _opts) do
    scope = conn.assigns[:current_scope]

    cond do
      is_nil(scope) ->
        Logger.debug("[auth] require_admin: no scope, redirecting to sign-in")

        conn
        |> maybe_store_return_to()
        |> redirect(to: SgiathAuth.WorkOS.sign_in_path())
        |> halt()

      is_nil(scope.admin) ->
        Logger.debug("[auth] require_admin: not admin, redirecting to /")

        conn
        |> redirect(to: "/")
        |> halt()

      :user_is_admin ->
        conn
    end
  end

  # LiveView Hooks
  # ==========================================================

  @doc """
  LiveView `on_mount` hooks for authentication and authorization.

  ## Available Hooks

  - `:mount_current_scope` - Loads user scope without requiring authentication
  - `:require_authenticated` - Requires authenticated user
  - `:require_organization` - Requires user with organization selected
  - `:require_admin` - Requires admin user
  - `:test_authenticated` - Test helper (only available in test env)

  ## Usage

      # In your LiveView
      on_mount {SgiathAuth, :require_authenticated}

      # Or in a live_session
      live_session :authenticated, on_mount: [{SgiathAuth, :require_authenticated}] do
        live "/dashboard", DashboardLive
      end

  ## Return Path

  When redirecting for token refresh, the hook attempts to determine the return path:

  1. Calls `YourLiveView.return_to(params)` if the function exists
  2. Falls back to `"/"` otherwise

  Implement `return_to/1` in your LiveView to customize:

      def return_to(%{"id" => id}), do: ~p"/items/\#{id}"
      def return_to(_), do: ~p"/items"
  """
  def on_mount(:mount_current_scope, _params, session, socket) do
    {:cont, mount_current_scope(socket, session)}
  end

  def on_mount(:require_authenticated, params, session, socket) do
    socket = mount_current_scope(socket, session)
    scope = socket.assigns[:current_scope]

    cond do
      is_nil(scope) and is_nil(session["access_token"]) ->
        {:halt, Phoenix.LiveView.redirect(socket, to: SgiathAuth.WorkOS.sign_in_path())}

      is_nil(scope) ->
        return_to = get_return_to(socket, params)
        {:halt, Phoenix.LiveView.redirect(socket, to: "/auth/refresh?return_to=#{return_to}")}

      :user_have_scope ->
        {:cont, socket}
    end
  end

  def on_mount(:require_organization, params, session, socket) do
    socket = mount_current_scope(socket, session)
    scope = socket.assigns[:current_scope]

    cond do
      is_nil(scope) and is_nil(session["access_token"]) ->
        {:halt, Phoenix.LiveView.redirect(socket, to: SgiathAuth.WorkOS.sign_in_path())}

      is_nil(scope) ->
        return_to = get_return_to(socket, params)
        {:halt, Phoenix.LiveView.redirect(socket, to: "/auth/refresh?return_to=#{return_to}")}

      is_nil(scope.org) ->
        return_to = get_return_to(socket, params)

        {:halt,
         Phoenix.LiveView.redirect(socket, to: "#{@no_org_redirect}?return_to=#{return_to}")}

      :logged_in_with_org ->
        {:cont, socket}
    end
  end

  def on_mount(:require_admin, params, session, socket) do
    socket = mount_current_scope(socket, session)
    scope = socket.assigns[:current_scope]

    cond do
      is_nil(scope) and is_nil(session["access_token"]) ->
        {:halt, Phoenix.LiveView.redirect(socket, to: SgiathAuth.WorkOS.sign_in_path())}

      is_nil(scope) ->
        return_to = get_return_to(socket, params)
        {:halt, Phoenix.LiveView.redirect(socket, to: "/auth/refresh?return_to=#{return_to}")}

      is_nil(scope.admin) ->
        {:halt, Phoenix.LiveView.redirect(socket, to: "/")}

      :user_is_admin ->
        {:cont, socket}
    end
  end

  if Mix.env() == :test do
    def on_mount(:test_authenticated, _params, session, socket) do
      case session do
        %{"test_scope" => %SgiathAuth.Scope{} = scope} ->
          {:cont, Phoenix.Component.assign(socket, :current_scope, scope)}

        _ ->
          {:halt, Phoenix.LiveView.redirect(socket, to: SgiathAuth.WorkOS.sign_in_path())}
      end
    end
  end

  # helpers
  # ==========================================================

  defp mount_current_scope(socket, session) do
    Phoenix.Component.assign_new(socket, :current_scope, fn ->
      build_scope_from_session(session)
    end)
  end

  defp build_scope_from_session(%{"access_token" => access_token} = session) do
    case build_scope_from_token(access_token) do
      {:ok, scope, session_id} ->
        Logger.metadata(session_id: session_id)
        org = load_organization(session["org_id"])
        %{scope | org: org}

      {:error, _reason} ->
        # Token invalid - will be handled by require_authenticated if needed
        nil
    end
  end

  defp build_scope_from_session(_session), do: nil

  defp load_organization(nil), do: nil

  defp load_organization(org_id) do
    case Organization.get(org_id) do
      {:ok, org} -> org
      {:error, _} -> nil
    end
  end

  defp maybe_store_return_to(%{method: "GET"} = conn) do
    put_session(conn, :user_return_to, current_path(conn))
  end

  defp maybe_store_return_to(conn), do: conn

  defp get_return_to(socket, params) do
    if function_exported?(socket.view, :return_to, 1) do
      socket.view.return_to(params)
    else
      "/"
    end
  end

  defp build_scope_from_token(access_token) do
    with {:ok, %{"sub" => user_id, "role" => role, "sid" => session_id}} <-
           SgiathAuth.Token.verify_and_validate(access_token),
         {:ok, user} <- SgiathAuth.WorkOS.get_user(user_id) do
      {:ok, SgiathAuth.Scope.for_user(user, role), session_id}
    end
  end

  defp refresh_params(params) do
    params = params || %{}
    org_id = Map.get(params, "organization_id") || Map.get(params, :organization_id)

    if is_binary(org_id) and org_id != "" do
      %{"organization_id" => org_id}
    else
      %{}
    end
  end

  defp maybe_put_org_id(conn, response) do
    case Map.fetch(response, "organization_id") do
      {:ok, org_id} -> put_session(conn, :org_id, org_id)
      :error -> conn
    end
  end

  defp ensure_organization(conn, org_id, _user) when is_binary(org_id) do
    case Organization.get(org_id) do
      {:ok, org} -> {conn, org}
      {:error, _} -> {conn, nil}
    end
  end

  defp ensure_organization(conn, _org_id, _user), do: {conn, nil}

  if Code.ensure_loaded?(PostHog) do
    defp set_context(properties) do
      Logger.metadata(properties)
      PostHog.set_context(%{distinct_id: properties.user_id})
    end
  else
    defp set_context(properties) do
      Logger.metadata(properties)
    end
  end
end
