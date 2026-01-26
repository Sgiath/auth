defmodule SgiathAuth.Supervisor do
  @moduledoc """
  """
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    children = [
      {SgiathAuth.Token.Strategy, time_interval: 2_000}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
