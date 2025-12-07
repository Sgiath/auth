defmodule SgiathAuth.MixProject do
  use Mix.Project

  def project do
    [
      app: :sgiath_auth,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:phoenix, "~> 1.8"},
      {:phoenix_live_view, "~> 1.1"},
      {:req, "~> 0.5"},
      {:joken, "~> 2.6"},
      {:joken_jwks, "~> 1.7"},
      {:posthog, "~> 2.1", optional: true}
    ]
  end
end
