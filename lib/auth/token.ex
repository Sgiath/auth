defmodule SgiathAuth.Token do
  @moduledoc """
  """
  use Joken.Config

  add_hook(JokenJwks, strategy: SgiathAuth.Token.Strategy)

  @impl Joken.Config
  def token_config do
    base_url = SgiathAuth.WorkOS.Client.base_url()
    client_id = SgiathAuth.WorkOS.Client.client_id()

    default_claims(iss: "#{base_url}/user_management/#{client_id}")
  end
end

defmodule SgiathAuth.Token.Strategy do
  use JokenJwks.DefaultStrategyTemplate

  def init_opts(opts) do
    base_url = SgiathAuth.WorkOS.Client.base_url()
    client_id = SgiathAuth.WorkOS.Client.client_id()

    Keyword.merge(opts, jwks_url: "#{base_url}/sso/jwks/#{client_id}")
  end
end
