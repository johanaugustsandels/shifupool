defmodule Bmbpool.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  require Logger
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Poolstate.System,
      Payout.System,
      Nodes.System,
      Users.System,
      HistoryChart.System,
      Supervisor.child_spec({TruncatedLog, BlockreqLog}, id: :blockreq),
      Supervisor.child_spec({TruncatedLog, :failed_requests}, id: :failed_requests),
      Supervisor.child_spec({TruncatedLog, :submits}, id: :submits),
      Supervisor.child_spec({TruncatedLog, :txs}, id: :txs),

      # start pheonix related stuff
      # Start the Telemetry supervisor
      BmbpoolWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Bmbpool.PubSub},
      # Start the Endpoint (http/https)
      BmbpoolWeb.Endpoint
      # Start a worker by calling: Bmbpool.Worker.start_link(arg)
      # {Bmbpool.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Bmbpool.Supervisor]

    Logger.info("Backend port is #{Application.fetch_env!(:bmbpool, :backend_port)}")
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    BmbpoolWeb.Endpoint.config_change(changed, removed)
    :ok
  end

end
