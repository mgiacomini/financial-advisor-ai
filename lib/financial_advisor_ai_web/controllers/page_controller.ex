defmodule FinancialAdvisorAiWeb.PageController do
  use FinancialAdvisorAiWeb, :controller

  def home(conn, _params) do
    case conn.assigns[:current_user] do
      nil ->
        # Unauthenticated user - redirect to Google OAuth
        conn
        |> redirect(to: ~p"/auth/google")

      _user ->
        # Authenticated user - redirect to chat
        conn
        |> redirect(to: ~p"/chat")
    end
  end
end
