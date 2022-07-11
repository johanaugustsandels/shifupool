
defmodule Poolstate.System do
  use Supervisor
  def start_link(_) do
    Supervisor.start_link(__MODULE__, nil,name: __MODULE__)
  end

  @impl true
  def init(_) do
    children = [
      Poolstate.DB,
      Poolstate.POWSet,
      Poolstate.Mining
    ]
    Supervisor.init(children,strategy: :rest_for_one)
  end
end
