defmodule FinancialAdvisorAiWeb.Router do
  use FinancialAdvisorAiWeb, :router

  import FinancialAdvisorAiWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {FinancialAdvisorAiWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :authenticated do
    plug :require_authenticated_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", FinancialAdvisorAiWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  scope "/", FinancialAdvisorAiWeb do
    pipe_through [:browser, :authenticated]

    live "/chat", ChatLive.Index, :index
  end

  # Authentication routes
  scope "/auth", FinancialAdvisorAiWeb do
    pipe_through :browser

    get "/logout", AuthController, :logout
    delete "/logout", AuthController, :logout

    # OAuth routes
    get "/:provider", AuthController, :request
    get "/:provider/callback", AuthController, :callback
    post "/:provider/callback", AuthController, :callback
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:financial_advisor_ai, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: FinancialAdvisorAiWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
