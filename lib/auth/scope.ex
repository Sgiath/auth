defmodule SgiathAuth.Scope do
  @moduledoc false

  require Logger

  defstruct user: nil, profile: nil, admin: nil

  def for_user(user, admin \\ nil)

  def for_user(%{} = user, admin) do
    profile = load_profile(user)
    %__MODULE__{user: user, profile: profile, admin: admin}
  end

  def for_user(nil, _admin), do: nil

  defp load_profile(user) do
    case Application.get_env(:sgiath_auth, :profile_module) do
      nil -> nil
      module -> module.load_profile(user)
    end
  end
end
