defmodule SgiathAuth.WorkOS do
  @moduledoc """
  Module for working with WorkOS.
  """

  require Logger

  @api_base_url "https://api.workos.com"

  def get_authorization_url(opts \\ []) do
    # if an organization ID is set in the config, add it to the query
    query =
      Application.fetch_env(:sgiath_auth, :workos_organization_id)
      |> case do
        {:ok, organization_id} -> Keyword.put_new(opts, :organization_id, organization_id)
        :error -> opts
      end
      # default sign-in if not specified
      |> Keyword.put_new(:screen_hint, "sign-in")
      |> Keyword.put_new(:state, "")
      |> Keyword.merge(
        provider: "authkit",
        response_type: "code",
        client_id: client_id(),
        redirect_uri: callback_url()
      )

    {:ok, "#{@api_base_url}/user_management/authorize?#{URI.encode_query(query)}"}
  end

  def get_logout_url(session_id) do
    query = [
      client_id: client_id(),
      session_id: session_id
    ]

    {:ok, "#{@api_base_url}/user_management/sessions/logout?#{URI.encode_query(query)}"}
  end

  # conn is here to add IP and user agent to the request later
  def authenticate_with_code(_conn, code) do
    Req.post(
      base_url: @api_base_url,
      url: "/user_management/authenticate",
      json: %{
        code: code,
        client_id: client_id(),
        client_secret: client_secret(),
        grant_type: "authorization_code"
      }
    )
    |> handle_response()
  end

  def authenticate_with_refresh_token(_conn, refresh_token) do
    Req.post(
      base_url: @api_base_url,
      url: "/user_management/authenticate",
      json: %{
        client_id: client_id(),
        client_secret: client_secret(),
        grant_type: "refresh_token",
        refresh_token: refresh_token
      }
    )
    |> handle_response()
  end

  def get_user(user_id) do
    Req.get(
      base_url: @api_base_url,
      url: "/user_management/users/#{user_id}",
      auth: {:bearer, client_secret()}
    )
    |> handle_response()
  end

  def base_url, do: @api_base_url

  def client_id do
    Application.fetch_env!(:sgiath_auth, :workos_client_id)
  end

  def client_secret do
    Application.fetch_env!(:sgiath_auth, :workos_secret_key)
  end

  defp callback_url do
    Application.fetch_env!(:sgiath_auth, :callback_url)
  end

  def sign_in_path do
    Application.get_env(:sgiath_auth, :sign_in_path, "/sign-in")
  end

  def default_path do
    Application.get_env(:sgiath_auth, :default_path, "/")
  end

  def profile_module do
    Application.get_env(:sgiath_auth, :profile_module)
  end

  defp handle_response({:ok, %Req.Response{status: 200, body: body}}) do
    {:ok, body}
  end

  defp handle_response({:ok, %Req.Response{status: 400, body: body}}) do
    Logger.error(
      "[WorkOS] The request was not acceptable. Check that the parameters were correct.",
      body: body
    )

    {:error, :bad_request}
  end

  defp handle_response({:ok, %Req.Response{status: 401}}) do
    Logger.error("[WorkOS] The API key used was invalid.")
    {:error, :unauthorized}
  end

  defp handle_response({:ok, %Req.Response{status: 403}}) do
    Logger.error("[WorkOS] The API key used did not have the correct permissions.")
    {:error, :forbidden}
  end

  defp handle_response({:ok, %Req.Response{status: 404}}) do
    Logger.error("[WorkOS] The resource was not found.")
    {:error, :not_found}
  end

  defp handle_response({:ok, %Req.Response{status: 422}}) do
    Logger.error(
      "[WorkOS] Validation failed for the request. Check that the parameters were correct."
    )

    {:error, :unprocessable_entity}
  end

  defp handle_response({:ok, %Req.Response{status: 429}}) do
    Logger.error("[WorkOS] Too many requests.")
    {:error, :too_many_requests}
  end

  defp handle_response({:ok, %Req.Response{status: status, body: body}}) when status >= 500 do
    Logger.error("[WorkOS] Error with WorkOS servers.", body: body)
    {:error, :internal_server_error}
  end

  defp handle_response({:error, %{reason: reason}}) do
    Logger.error("[WorkOS] Error with the request.", reason: reason)
    {:error, :request_error}
  end
end
