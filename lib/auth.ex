defmodule SgiathAuth do
  import Plug.Conn
  import Phoenix.Controller

  require Logger

  def fetch_current_scope(conn, opts) do
    Logger.debug("[auth] fetching current scope")

    with {:session, %{"access_token" => access_token, "refresh_token" => refresh_token}} <-
           {:session, get_session(conn)},
         {:scope, {:ok, scope, session_id}} <-
           {:scope, build_scope_from_token(access_token)} do
      set_context(%{
        user_id: scope.user["id"],
        profile_id: get_in(scope.profile.id),
        session_id: session_id
      })

      conn
      |> put_session(:access_token, access_token)
      |> put_session(:refresh_token, refresh_token)
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
  Refreshes the session tokens using the refresh token stored in the session.
  Returns the conn with updated tokens on success, or clears the session on failure.
  """
  def refresh_session(conn) do
    refresh_token = get_session(conn, :refresh_token)

    case SgiathAuth.WorkOS.authenticate_with_refresh_token(conn, refresh_token) do
      {:ok, response} ->
        Logger.debug("[auth] refreshed session successfully")

        conn
        |> put_session(:access_token, response["access_token"])
        |> put_session(:refresh_token, response["refresh_token"])

      {:error, reason} ->
        Logger.debug("[auth] failed to refresh session, reason: #{inspect(reason)}")

        delete_csrf_token()

        conn
        |> configure_session(renew: true)
        |> clear_session()
    end
  end

  defp build_scope_from_token(access_token) do
    with {:ok, %{"sub" => user_id, "role" => role, "sid" => session_id} = token} <-
           SgiathAuth.Token.verify_and_validate(access_token),
         {:ok, user} <- SgiathAuth.WorkOS.get_user(user_id) do
      impersonator = get_in(token, ["act", "sub"])
      {:ok, SgiathAuth.Scope.for_user(user, role, impersonator), session_id}
    end
  end

  def on_mount(:mount_current_scope, _params, session, socket) do
    {:cont, mount_current_scope(socket, session)}
  end

  def on_mount(:require_authenticated, _params, session, socket) do
    socket = mount_current_scope(socket, session)

    cond do
      socket.assigns.current_scope && socket.assigns.current_scope.user ->
        {:cont, socket}

      # Has token but scope building failed - try to refresh
      session["access_token"] ->
        {:halt, Phoenix.LiveView.redirect(socket, to: SgiathAuth.WorkOS.refresh_path())}

      # No token at all - redirect to sign in
      true ->
        {:halt, Phoenix.LiveView.redirect(socket, to: SgiathAuth.WorkOS.sign_in_path())}
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

  defp mount_current_scope(socket, session) do
    Phoenix.Component.assign_new(socket, :current_scope, fn ->
      case session do
        %{"access_token" => access_token} ->
          case build_scope_from_token(access_token) do
            {:ok, scope, session_id} ->
              Logger.metadata(session_id: session_id)
              scope

            {:error, _reason} ->
              # Token invalid - will be handled by require_authenticated if needed
              nil
          end

        _ ->
          nil
      end
    end)
  end

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

  defp maybe_store_return_to(%{method: "GET"} = conn) do
    put_session(conn, :user_return_to, current_path(conn))
  end

  defp maybe_store_return_to(conn), do: conn

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
