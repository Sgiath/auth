defmodule SgiathAuth.WorkOS.ApiKeys do
  @moduledoc """
  WorkOS API Keys management.

  Provides functions to list, create, delete, and validate API keys for an organization.

  https://workos.com/docs/reference/authkit/api-keys
  """

  alias SgiathAuth.WorkOS.Client

  @doc """
  Lists API keys for an organization.

  ## Options

    * `:limit` - Maximum number of results to return (integer)
    * `:before` - Pagination cursor for previous page (string)
    * `:after` - Pagination cursor for next page (string)
    * `:order` - Sort order, `:asc` or `:desc`

  """
  def list("org_" <> org_id, opts \\ []) do
    Client.new()
    |> Req.get(url: "/organizations/org_#{org_id}/api_keys", query: opts)
    |> Client.handle_response()
  end

  @doc """
  Creates a new API key for an organization.

  ## Parameters

    * `org_id` - The organization ID
    * `name` - Name for the API key
    * `permissions` - List of permissions to grant (default: `[]`)

  """
  def create("org_" <> org_id, name, permissions \\ []) do
    Client.new()
    |> Req.post(
      url: "/organizations/org_#{org_id}/api_keys",
      json: %{name: name, permissions: permissions}
    )
    |> Client.handle_response()
  end

  @doc """
  Deletes an API key by its ID.
  """
  def delete("api_key_" <> api_key_id) do
    Client.new()
    |> Req.delete(url: "/api_keys/api_key_#{api_key_id}")
    |> Client.handle_response()
  end

  @doc """
  Validates an API key and returns its metadata if valid.
  """
  def validate(api_key) do
    Client.new()
    |> Req.post(url: "/api_keys/validations", json: %{value: api_key})
    |> Client.handle_response()
  end
end
