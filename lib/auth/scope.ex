defmodule SgiathAuth.Scope do
  @moduledoc false

  require Logger

  @derive JSON.Encoder
  defstruct user: nil, org: nil, profile: nil, admin: nil, role: nil

  def for_user(user, role \\ "member")

  def for_user(%{} = user, role) do
    profile = load_profile(user)
    admin = load_admin(user)
    %__MODULE__{user: user, profile: profile, role: role, admin: admin}
  end

  def for_user(nil, _role), do: nil

  defp load_profile(user) do
    case Application.get_env(:sgiath_auth, :profile_module) do
      nil -> nil
      module -> module.load_profile(user)
    end
  end

  defp load_admin(user) do
    module = Application.get_env(:sgiath_auth, :profile_module)

    if not is_nil(module) and Code.ensure_loaded?(module) and
         function_exported?(module, :load_admin, 1) do
      module.load_admin(user)
    else
      nil
    end
  end
end
