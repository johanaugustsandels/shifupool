defmodule Nodes.System do
  use Supervisor
  def start_link(_) do
    Supervisor.start_link(__MODULE__, nil, name: __MODULE__)
  end
  @impl true
  def init(_) do
    children = [
      Nodes.GenServer,
      Nodes.Agent,
      Nodes.HashrateTask
    ]
    Supervisor.init(children, strategy: :one_for_one)
  end
end
