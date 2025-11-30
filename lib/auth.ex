defmodule SgiathAuth do
  import Plug.Conn
  import Phoenix.Controller

  require Logger

  def fetch_current_scope(conn, opts) do
    Logger.debug("[auth] fetching current scope")

    with {:session, %{"access_token" => access_token, "refresh_token" => refresh_token}} <-
           {:session, get_session(conn)},
         {:token, {:ok, %{"sub" => user_id, "sid" => session_id} = token}} <-
           {:token, SgiathAuth.Token.verify_and_validate(access_token)},
         {:user, {:ok, user}} <- {:user, SgiathAuth.WorkOS.get_user(user_id)} do
      Logger.metadata(session_id: session_id)

      admin = get_in(token, ["act", "sub"])
      scope = SgiathAuth.Scope.for_user(user, admin)

      conn
      |> put_session(:access_token, access_token)
      |> put_session(:refresh_token, refresh_token)
      |> put_session(:live_socket_id, session_id)
      |> put_session(:current_scope, scope)
      |> assign(:current_scope, scope)
    else
      {:session, %{}} ->
        Logger.debug("[auth] session without access token")
        assign(conn, :current_scope, SgiathAuth.Scope.for_user(nil))

      {:token, {:error, _reason}} ->
        # Prevent infinite recursion - only attempt refresh once
        if conn.private[:auth_refresh_attempted] do
          Logger.debug("[auth] refresh already attempted, giving up")
          assign(conn, :current_scope, SgiathAuth.Scope.for_user(nil))
        else
          Logger.debug("[auth] refreshing session")

          conn
          |> put_private(:auth_refresh_attempted, true)
          |> refresh_session()
          |> fetch_current_scope(opts)
        end

      {:user, {:error, reason}} ->
        Logger.warning("[auth] failed to fetch user, reason: #{inspect(reason)}")
        assign(conn, :current_scope, SgiathAuth.Scope.for_user(nil))
    end
  end

  defp refresh_session(conn) do
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

  def on_mount(:mount_current_scope, _params, session, socket) do
    {:cont, mount_current_scope(socket, session)}
  end

  def on_mount(:require_authenticated, _params, session, socket) do
    socket = mount_current_scope(socket, session)

    if socket.assigns.current_scope && socket.assigns.current_scope.user do
      {:cont, socket}
    else
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
    Phoenix.Component.assign_new(socket, :current_scope, fn -> session["current_scope"] end)
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
end
