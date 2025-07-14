defmodule FinancialAdvisorAi.Tasks.EmailWorker do
  use Oban.Worker, queue: :default

  alias FinancialAdvisorAi.Integrations

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"user_id" => user_id, "to" => to, "subject" => subject, "body" => body}
      }) do
    Logger.info("Sending email for user #{user_id} to #{to} with subject '#{subject}'")
    token = Integrations.get_google_oauth_token(user_id)

    email_data = %{
      raw: build_raw_email(to, subject, body)
    }

    # Send email
    case Integrations.GoogleClient.send_email(token.access_token, email_data) do
      {:ok, _response} ->
        Logger.info("Email sent successfully")

      {:error, error} ->
        Logger.error("Failed to send email: #{inspect(error)}")
        {:error, error}
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
