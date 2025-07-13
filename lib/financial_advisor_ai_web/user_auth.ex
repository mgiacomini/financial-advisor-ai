defmodule FinancialAdvisorAiWeb.UserAuth do
  @moduledoc """
  Authentication helpers for routes and controllers
  """
  import Plug.Conn
  import Phoenix.Controller

  alias FinancialAdvisorAi.Accounts

  # Session-based authentication

  def fetch_current_user(conn, _opts) do
    user_id = get_session(conn, :user_id)

    user = user_id && Accounts.get_user(user_id)
    assign(conn, :current_user, user)
  end

  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_flash(:error, "You must log in to access this page.")
      |> redirect(to: "/")
      |> halt()
    end
  end

  def require_admin_user(conn, _opts) do
    user = conn.assigns[:current_user]

    if user && user.admin do
      conn
    else
      conn
      |> put_flash(:error, "You must be an admin to access this page.")
      |> redirect(to: "/")
      |> halt()
    end
  end

  # API authentication

  def require_authenticated_user_api(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "Authentication required"})
      |> halt()
    end
  end

  # Auth helpers

  def log_in_user(conn, user) do
    conn
    |> put_session(:user_id, user.id)
    |> configure_session(renew: true)
  end

  def log_out_user(conn) do
    conn
    |> configure_session(drop: true)
    |> redirect(to: "/")
  end
end
