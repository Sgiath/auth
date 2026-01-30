defmodule SgiathAuth.WorkOS.Client do
  @moduledoc false
  require Logger

  @api_base_url "https://api.workos.com"

  def new do
    defaults = [base_url: base_url(), auth: {:bearer, client_secret()}]
    extra = Application.get_env(:sgiath_auth, :workos_req_options, [])

    defaults
    |> Keyword.merge(extra)
    |> Req.new()
  end

  def base_url, do: @api_base_url

  def client_id do
    Application.fetch_env!(:sgiath_auth, :workos_client_id)
  end

  def client_secret do
    Application.fetch_env!(:sgiath_auth, :workos_secret_key)
  end

  def handle_response({:ok, %Req.Response{status: 200, body: body}}) do
    {:ok, body}
  end

  def handle_response({:ok, %Req.Response{status: 201, body: body}}) do
    {:ok, body}
  end

  def handle_response({:ok, %Req.Response{status: 204}}), do: :ok

  def handle_response({:ok, %Req.Response{status: 400, body: body}}) do
    Logger.error(
      "[WorkOS] The request was not acceptable. Check that the parameters were correct.",
      body: body
    )

    {:error, :bad_request}
  end

  def handle_response({:ok, %Req.Response{status: 401}}) do
    Logger.error("[WorkOS] The API key used was invalid.")
    {:error, :unauthorized}
  end

  def handle_response({:ok, %Req.Response{status: 403}}) do
    Logger.error("[WorkOS] The API key used did not have the correct permissions.")
    {:error, :forbidden}
  end

  def handle_response({:ok, %Req.Response{status: 404}}) do
    Logger.error("[WorkOS] The resource was not found.")
    {:error, :not_found}
  end

  def handle_response({:ok, %Req.Response{status: 422}}) do
    Logger.error(
      "[WorkOS] Validation failed for the request. Check that the parameters were correct."
    )

    {:error, :unprocessable_entity}
  end

  def handle_response({:ok, %Req.Response{status: 429}}) do
    Logger.error("[WorkOS] Too many requests.")
    {:error, :too_many_requests}
  end

  def handle_response({:ok, %Req.Response{status: status, body: body}}) when status >= 500 do
    Logger.error("[WorkOS] Error with WorkOS servers.", body: body)
    {:error, :internal_server_error}
  end

  def handle_response({:error, %{reason: reason}}) do
    Logger.error("[WorkOS] Error with the request.", reason: reason)
    {:error, :request_error}
  end
end
