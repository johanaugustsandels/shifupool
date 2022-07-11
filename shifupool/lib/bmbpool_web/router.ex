defmodule BmbpoolWeb.Router do
  use BmbpoolWeb, :router

  pipeline :browser do
    plug :ratelimit
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {BmbpoolWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :ratelimit
  end

  scope "/", BmbpoolWeb do
    pipe_through :browser

    get "/", PageController, :index
    get "/account/:account", PageController, :account
    get "/failed", PageController, :failed
    get "/txs", PageController, :txs
    get "/wallet", PageController, :wallet
    get "/worker/:worker", PageController, :worker
    get "/rounds", PageController, :rounds
    get "/round/:round", PageController, :round
    get "/submitted", PageController, :submitted
  end

  scope "/api/", BmbpoolWeb do
    pipe_through :api

    get "/state", ApiController, :state
    get "/letshashit_state", ApiController, :lhi_state
    get "/user/:wallet", ApiController, :user
  end

  def ratelimit(conn, _opts) do
    with {:ok, _} <- ExRated.check_rate({1,conn.remote_ip}, 600_000, 50),
         {:ok, _} <- ExRated.check_rate(conn.remote_ip, 30_000, 10),
         {:ok, _} <- ExRated.check_rate(:overall, 1_000, 10)
    do
      conn
    else
      _ -> text(conn, "RATE-LIMITED") |> halt()
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", BmbpoolWeb do
  #   pipe_through :api
  # end
end
