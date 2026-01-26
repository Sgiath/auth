defmodule SgiathAuth.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :sgiath_auth,
      version: @version,
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),

      name: "Nostr Lib",
      source_url: "https://github.com/Sgiath/nostr-lib",
      homepage_url: "https://sgiath.dev/libraries#nostr_lib",
      description: """
      Library which implements Nostr specs
      """,
      package: package(),
      docs: docs()
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

  defp aliases do
    [
      precommit: ["compile --warning-as-errors", "deps.unlock --unused", "format", "test"]
    ]
  end

  # Documentation
  defp package do
    [
      name: "sgiath_auth",
      maintainers: ["sgiath <sgiath@sgiath.dev>"],
      files: ~w(lib .formatter.exs mix.exs usage-rules.md README* LICENSE*),
      licenses: ["WTFPL"],
      links: %{
        "GitHub" => "https://github.com/Sgiath/sgiath-auth"
      }
    ]
  end

  defp docs do
    [
      authors: ["Sgiath <sgiath@sgiath.dev>"],
      main: "overview",
      api_reference: false,
      formatters: ["html"],
      source_ref: "v#{@version}",
      source_url: "https://github.com/sgiath/sgiath-auth",
    ]
  end
end
