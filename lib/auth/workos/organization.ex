defmodule SgiathAuth.WorkOS.Organization do
  @moduledoc """
  WorkOS Organizations API client.

  See https://workos.com/docs/reference/organization
  """

  alias SgiathAuth.WorkOS.Client

  @doc """
  Fetches an organization by its WorkOS ID.
  """
  def get("org_" <> org_id) do
    Client.new()
    |> Req.get(url: "/organizations/org_#{org_id}")
    |> Client.handle_response()
  end

  @doc """
  Fetches an organization by its external ID.
  """
  def get_by_external_id(external_id) do
    Client.new()
    |> Req.get(url: "/organizations/external_id/#{external_id}")
    |> Client.handle_response()
  end

  @doc """
  Lists organizations with optional filters.

  ## Options

    * `:domains` - list of domain strings to filter by
    * `:limit` - maximum number of results (integer)
    * `:before` - pagination cursor for previous page
    * `:after` - pagination cursor for next page
    * `:order` - sort order (`:asc` or `:desc`)
  """
  def list(opts \\ []) do
    Client.new()
    |> Req.get(url: "/organizations", params: opts)
    |> Client.handle_response()
  end

  @doc """
  Creates a new organization.

  ## Options

    * `:domain_data` - list of maps with `:domain` (string) and `:state` (`:pending` or `:verified`)
    * `:external_id` - external identifier string
    * `:metadata` - arbitrary metadata map
  """
  def create(name, opts \\ %{}) do
    Client.new()
    |> Req.post(url: "/organizations", json: Map.put(opts, :name, name))
    |> Client.handle_response()
  end

  @doc """
  Updates an existing organization.

  ## Options

    * `:domain_data` - list of maps with `:domain` (string) and `:state` (`:pending` or `:verified`)
    * `:external_id` - external identifier string
    * `:metadata` - arbitrary metadata map
  """
  def update("org_" <> org_id, name, opts \\ %{}) do
    Client.new()
    |> Req.put(url: "/organizations/org_#{org_id}", json: Map.put(opts, :name, name))
    |> Client.handle_response()
  end

  @doc """
  Deletes an organization by its WorkOS ID.
  """
  def delete("org_" <> org_id) do
    Client.new()
    |> Req.delete(url: "/organizations/org_#{org_id}")
    |> Client.handle_response()
  end
end
