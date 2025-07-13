# Add to config/config.exs:
#
#   config :financial_advisor_ai,
#     FinancialAdvisorAi.Repo,
#     types: FinancialAdvisorAi.Extensions.Ecto.PostgrexTypes

Postgrex.Types.define(
  FinancialAdvisorAi.Extensions.Ecto.PostgrexTypes,
  Pgvector.extensions() ++ Ecto.Adapters.Postgres.extensions()
)
