defmodule TruncatedLog do
  use GenServer
  @logsize 100

  @doc false
  def start_link(name) do
    GenServer.start_link(__MODULE__, nil, name: name)
  end

  @impl true
  def init(_) do
    {:ok, []}
  end

  @impl true
  def handle_cast({:log, msg}, state) do
    state=[msg | state]
    |>List.delete_at(@logsize)
    {:noreply, state}
  end
  @impl true
  def handle_call(:get,_from,state) do
    {:reply,state,state}
  end

  def log(pid,msg) when is_binary(msg) do
    GenServer.cast(pid, {:log, msg})
  end
  def get(pid)  do
    GenServer.call(pid, :get)
  end
end
