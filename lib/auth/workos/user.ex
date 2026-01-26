defmodule SgiathAuth.WorkOS.User do
  @moduledoc """
  WorkOS Users API client.

  Provides functions to retrieve, list, create, update, and delete users.

  See https://workos.com/docs/reference/authkit/user
  """
  alias SgiathAuth.WorkOS.Client

  @doc """
  Fetches a user by its WorkOS ID.
  """
  def get("user_" <> user_id) do
    Client.new()
    |> Req.get(url: "/user_management/users/user_#{user_id}")
    |> Client.handle_response()
  end

  @doc """
  Fetches a user by its external ID.
  """
  def get_by_external_id(external_id) do
    Client.new()
    |> Req.get(url: "/user_management/users/external_id/#{external_id}")
    |> Client.handle_response()
  end

  @doc """
  Lists users with optional filters.

  ## Options

    * `:email` - filter by email (string)
    * `:organization_id` - filter by organization ID (string)
    * `:limit` - maximum number of results (integer)
    * `:before` - pagination cursor for previous page (string)
    * `:after` - pagination cursor for next page (string)
    * `:order` - sort order, `:asc` or `:desc`
  """
  def list(params \\ []) do
    Client.new()
    |> Req.get(url: "/user_management/users", query: params)
    |> Client.handle_response()
  end

  @doc """
  Creates a new user.

  ## Options

    * `:password` - password (string)
    * `:password_hash` - hashed password (string)
    * `:password_hash_type` - hash type (string)
    * `:first_name` - first name (string)
    * `:last_name` - last name (string)
    * `:email_verified` - mark email as verified (boolean)
    * `:external_id` - external identifier (string)
    * `:metadata` - arbitrary metadata map
  """
  def create(email, params \\ %{}) do
    Client.new()
    |> Req.post(url: "/user_management/users", json: Map.put(params, :email, email))
    |> Client.handle_response()
  end

  @doc """
  Updates an existing user.

  ## Options

    * `:first_name` - first name (string)
    * `:last_name` - last name (string)
    * `:email` - email (string)
    * `:email_verified` - mark email as verified (boolean)
    * `:password` - password (string)
    * `:password_hash` - hashed password (string)
    * `:password_hash_type` - hash type (string)
    * `:external_id` - external identifier (string)
    * `:metadata` - arbitrary metadata map
    * `:locale` - locale string
  """
  def update("user_" <> user_id, params \\ %{}) do
    Client.new()
    |> Req.put(url: "/user_management/users/user_#{user_id}", json: params)
    |> Client.handle_response()
  end

  @doc """
  Deletes a user by its WorkOS ID.
  """
  def delete("user_" <> user_id) do
    Client.new()
    |> Req.delete(url: "/user_management/users/user_#{user_id}")
    |> Client.handle_response()
  end
end
