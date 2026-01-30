import Config

config :sgiath_auth, no_organization_redirect: "/setup"

import_config "#{config_env()}.exs"
