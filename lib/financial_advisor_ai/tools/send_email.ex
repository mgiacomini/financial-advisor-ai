defmodule FinancialAdvisorAi.Tools.SendEmail do
  @moduledoc "Send emails using the configured email service"

  alias FinancialAdvisorAi.Tasks

  require Logger

  ## Tool specification for OpenAI API

  @open_api_spec %{
    type: "function",
    function: %{
      name: "send_email",
      description: "Send an email",
      parameters: %{
        type: "object",
        properties: %{
          to: %{type: "string", description: "Recipient email"},
          subject: %{type: "string"},
          body: %{type: "string"}
        },
        required: ["to", "subject", "body"]
      }
    }
  }

  @spec open_api_spec() :: map()
  def open_api_spec, do: @open_api_spec

  ## Tool call implementation

  @doc """
  Sends an email for a user.

  ## Parameters
    - user_id: The ID of the user
    - to: Recipient email address
    - subject: Email subject
    - body: Email body content

  ## Returns
    - {:ok, Oban.Job.t()} on success
    - {:error, Ecto.Changeset.t()} on failure
  """
  @spec call(integer(), String.t(), String.t(), String.t()) ::
          {:ok, Oban.Job.t()} | {:error, Ecto.Changeset.t()}
  def call(user_id, to, subject, body) do
    Logger.info("Sending email for user #{user_id} to #{to} with subject: #{subject}")

    {:ok, _} =
      %{user_id: user_id, to: to, subject: subject, body: body}
      |> Tasks.EmailWorker.new()
      |> Oban.insert()

    {:ok, "Email scheduled for delivery"}
  end
end
