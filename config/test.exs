import Config

config :logger, level: :warning

config :sgiath_auth, no_organization_redirect: "/setup"

# Disable PostHog in tests by providing minimal config
config :posthog,
  api_host: "https://localhost",
  api_key: "test_key",
  disabled: true
