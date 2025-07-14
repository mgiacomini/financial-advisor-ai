# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :financial_advisor_ai,
  ecto_repos: [FinancialAdvisorAi.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures the ecto repository
config :financial_advisor_ai, FinancialAdvisorAi.Repo,
  types: FinancialAdvisorAi.Extensions.Ecto.PostgrexTypes

# Configures the endpoint
config :financial_advisor_ai, FinancialAdvisorAiWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: FinancialAdvisorAiWeb.ErrorHTML, json: FinancialAdvisorAiWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: FinancialAdvisorAi.PubSub,
  live_view: [signing_salt: "zKoZC+S3"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :financial_advisor_ai, FinancialAdvisorAi.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  financial_advisor_ai: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  financial_advisor_ai: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Ueberauth configuration
config :ueberauth, Ueberauth,
  providers: [
    google:
      {Ueberauth.Strategy.Google,
       [
         default_scope:
           "email profile https://www.googleapis.com/auth/gmail.readonly https://www.googleapis.com/auth/gmail.send https://www.googleapis.com/auth/calendar",
         access_type: "offline",
         prompt: "consent",
         include_granted_scopes: true
       ]}
  ]

config :ueberauth, Ueberauth.Strategy.Google.OAuth,
  client_id: System.get_env("GOOGLE_CLIENT_ID"),
  client_secret: System.get_env("GOOGLE_CLIENT_SECRET")

# Guardian configuration
config :financial_advisor_ai, FinancialAdvisorAi.Guardian,
  issuer: "financial_advisor_ai",
  secret_key: System.get_env("GUARDIAN_SECRET_KEY") || "your_default_secret_key"

# Oban configuration
config :financial_advisor_ai, Oban,
  engine: Oban.Engines.Basic,
  repo: FinancialAdvisorAi.Repo,
  plugins: [Oban.Plugins.Pruner],
  queues: [default: 10, emails: 20, sync: 5]

# Cloak encryption
default_cloak_key = 32 |> :crypto.strong_rand_bytes() |> Base.encode64()

config :financial_advisor_ai, FinancialAdvisorAi.Vault,
  ciphers: [
    default: {
      Cloak.Ciphers.AES.GCM,
      tag: "AES.GCM.V1",
      key: Base.decode64!(System.get_env("CLOAK_KEY") || default_cloak_key),
      iv_length: 12
    }
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
