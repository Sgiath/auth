defmodule SgiathAuth.Token do
  @moduledoc false
  use Joken.Config

  alias SgiathAuth.WorkOS.Client

  add_hook(JokenJwks, strategy: SgiathAuth.Token.Strategy)

  @impl Joken.Config
  def token_config do
    base_url = Client.base_url()
    client_id = Client.client_id()

    default_claims(iss: "#{base_url}/user_management/#{client_id}")
  end
end

defmodule SgiathAuth.Token.Strategy do
  @moduledoc false
  use JokenJwks.DefaultStrategyTemplate

  alias SgiathAuth.WorkOS.Client

  def init_opts(opts) do
    base_url = Client.base_url()
    client_id = Client.client_id()

    Keyword.merge(opts, jwks_url: "#{base_url}/sso/jwks/#{client_id}")
  end
end
