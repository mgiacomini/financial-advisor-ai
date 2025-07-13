defmodule FinancialAdvisorAi.Tasks.EmailWorker do
  use Oban.Worker, queue: :emails, max_attempts: 3

  alias FinancialAdvisorAi.Integrations

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"user_id" => user_id, "to" => to, "subject" => subject, "body" => body}
      }) do
    # Get user's Google token
    token = Integrations.get_google_oauth_token(user_id)

    # Prepare email
    email_data = %{
      raw: build_raw_email(to, subject, body)
    }

    # Send email
    case Integrations.GoogleClient.send_email(token.access_token, email_data) do
      {:ok, _response} -> :ok
      {:error, error} -> {:error, error}
    end
  end

  defp build_raw_email(to, subject, body) do
    email = """
    To: #{to}
    Subject: #{subject}
    Content-Type: text/plain; charset=utf-8

    #{body}
    """

    Base.encode64(email)
  end
end
