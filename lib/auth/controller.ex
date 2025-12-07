defmodule SgiathAuth.Controller do
  use Phoenix.Controller, formats: [:html, :json]

  import Plug.Conn

  def sign_in(conn, _params) do
    default = SgiathAuth.WorkOS.default_path()
    return_to = get_session(conn, :user_return_to, default)
    {:ok, url} = SgiathAuth.WorkOS.get_authorization_url(state: Base.encode64(return_to))

    redirect(conn, external: url)
  end

  def sign_out(conn, _params) do
    case get_session(conn, :access_token) do
      nil ->
        # No session, just redirect to home
        redirect(conn, to: SgiathAuth.WorkOS.default_path())

      access_token ->
        # Try to get session_id for WorkOS logout, but don't crash if it fails
        redirect_url =
          case SgiathAuth.Token.verify(access_token) do
            {:ok, %{"sid" => session_id}} ->
              {:ok, url} = SgiathAuth.WorkOS.get_logout_url(session_id)
              url

            _ ->
              SgiathAuth.WorkOS.default_path()
          end

        delete_csrf_token()

        conn
        |> configure_session(renew: true)
        |> clear_session()
        |> redirect(external: redirect_url)
    end
  end

  def refresh(conn, params) do
    return_to = Map.get(params, "return_to", SgiathAuth.WorkOS.default_path())
    validated_return_to = validate_relative_path(return_to, SgiathAuth.WorkOS.default_path())

    conn
    |> SgiathAuth.refresh_session()
    |> redirect(to: validated_return_to)
  end

  def sign_up(conn, _params) do
    default = SgiathAuth.WorkOS.default_path()
    return_to = get_session(conn, :user_return_to, default)

    {:ok, url} =
      SgiathAuth.WorkOS.get_authorization_url(
        screen_hint: "sign-up",
        state: Base.encode64(return_to)
      )

    redirect(conn, external: url)
  end

  def callback(conn, %{"error" => error, "error_description" => error_description}) do
    render(conn, :error, error: error, error_description: error_description)
  end

  def callback(conn, %{"code" => code, "state" => state}) do
    case SgiathAuth.WorkOS.authenticate_with_code(conn, code) do
      {:ok, response} ->
        conn
        |> authenticate(response)
        |> redirect(to: decode_return_path(state))

      {:error, reason} ->
        render(conn, :error, error: "authentication_failed", error_description: inspect(reason))
    end
  end

  def callback(conn, %{"code" => code}) do
    callback(conn, %{"code" => code, "state" => Base.encode64(SgiathAuth.WorkOS.default_path())})
  end

  defp authenticate(conn, %{"access_token" => access_token, "refresh_token" => refresh_token}) do
    conn
    |> put_session(:access_token, access_token)
    |> put_session(:refresh_token, refresh_token)
  end

  # Safely decode and validate the return path to prevent open redirect attacks
  defp decode_return_path(state) do
    default = SgiathAuth.WorkOS.default_path()

    case Base.decode64(state) do
      {:ok, path} -> validate_relative_path(path, default)
      :error -> default
    end
  end

  # Ensure it's not a protocol-relative URL like //evil.com
  defp validate_relative_path("//" <> _rest, default), do: default
  defp validate_relative_path("/" <> _rest = path, _default), do: path
  defp validate_relative_path(_, default), do: default
end
