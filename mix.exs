defmodule SgiathAuth.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :sgiath_auth,
      version: @version,
      elixir: "~> 1.19",
      elixirc_options: [warnings_as_errors: true],
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "Sgiath Auth",
      source_url: "https://github.com/sgiath/auth",
      homepage_url: "https://sgiath.dev/libraries#auth",
      description: """
      Opinionated authentication library for Phoenix applications
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

  def cli do
    [
      preferred_envs: ["test.watch": :test]
    ]
  end

  defp deps do
    [
      {:phoenix, "~> 1.8"},
      {:phoenix_live_view, "~> 1.1"},
      {:req, "~> 0.5"},
      {:joken, "~> 2.6"},
      {:joken_jwks, "~> 1.7"},
      {:posthog, "~> 2.1", optional: true},

      # testing and development
      {:ex_check, "~> 0.16", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:mix_test_watch, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false, warn_if_outdated: true}
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
        "GitHub" => "https://github.com/sgiath/auth"
      }
    ]
  end

  defp docs do
    [
      authors: ["sgiath <sgiath@sgiath.dev>"],
      main: "readme",
      extras: ["README.md", "usage-rules.md"],
      api_reference: false,
      formatters: ["html"],
      source_ref: "v#{@version}",
      source_url: "https://github.com/sgiath/auth"
    ]
  end
end
