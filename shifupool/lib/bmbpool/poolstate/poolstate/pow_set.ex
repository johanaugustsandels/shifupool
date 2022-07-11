defmodule Poolstate.POWSet do
  use Agent

  def start_link(_) do
    Agent.start_link(fn -> MapSet.new() end, name: __MODULE__)
  end

  def is_fresh(v) do
    Agent.get_and_update(
      __MODULE__,
      fn map ->
        if MapSet.member?(map, v) do
          {false, map}
        else
          {true, MapSet.put(map, v)}
        end
      end
    )
  end
  def reset do
    Agent.update(__MODULE__, fn _state -> MapSet.new() end)
  end
end
