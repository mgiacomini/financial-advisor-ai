defmodule FinancialAdvisorAiWeb.AuthController do
  use FinancialAdvisorAiWeb, :controller

  alias FinancialAdvisorAi.Accounts
  alias FinancialAdvisorAiWeb.UserAuth

  plug Ueberauth

  def request(conn, _params) do
    # Handled by Ueberauth
    conn
  end

  def callback(%{assigns: %{ueberauth_failure: failure}} = conn, _params) do
    conn
    |> put_flash(:error, "Authentication failed: #{inspect(failure.errors)}")
    |> redirect(to: "/")
  end

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    case Accounts.find_or_create_user(auth) do
      {:ok, user} ->
        # Save OAuth tokens
        {:ok, _token} = Accounts.create_or_update_oauth_token(user, auth)

        conn
        |> UserAuth.log_in_user(user)
        |> put_flash(:info, "Successfully authenticated!")
        |> redirect(to: "/chat")

      {:error, reason} ->
        conn
        |> put_flash(:error, "Authentication error: #{reason}")
        |> redirect(to: "/")
    end
  end

  def logout(conn, _params) do
    conn
    |> UserAuth.log_out_user()
    |> put_flash(:info, "Logged out successfully.")
  end
end
