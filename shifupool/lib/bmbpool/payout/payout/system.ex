defmodule Payout.System do
  use Supervisor

  @doc false
  def start_link(_) do
    Supervisor.start_link(__MODULE__, [],name: __MODULE__)
  end
  @impl true
  def init(_) do
    children=[
      Payout.Genserver
    ]
    Supervisor.init(children,strategy: :one_for_one)
  end

end
