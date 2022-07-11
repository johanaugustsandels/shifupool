defmodule Payout.Genserver do
  use GenServer
  
  @doc false
  def start_link(_) do
    GenServer.start_link(__MODULE__, [],name: __MODULE__)
  end

  @impl true
  def handle_info(msg,state) do
    state=
    case msg do
      {:DOWN, _, _, _, _} ->state
      {_ref, :payout_done} ->
        true = !is_nil(state.task)
        Poolstate.Mining.notify_processed_block()
        %{state| processing_round: nil,
          task: nil}
      _ ->state
    end
    {:noreply,state}
  end

  @impl true
  def handle_cast({:notify,round},state) do
    state=
    if state.task==nil do
      %{state|
        processing_round: round,
        task: Payout.Task.async(round)
      }
    else
      state
    end
    {:noreply,state}
  end

  @impl true
  def handle_call(:job,_from,state) do
    {:reply,state.processing_round,state}
  end
  
  @impl true
  def init(_) do
    state=%{
      processing_round: nil,
      task: nil
    }
    {:ok, state}
  end

  def notify(round) when is_integer(round) do
    GenServer.cast(__MODULE__,{:notify,round})
  end
  def job() do
    GenServer.call(__MODULE__,:job)
  end
end
