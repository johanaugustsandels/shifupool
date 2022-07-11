defmodule Nodes.Agent do
  defstruct [{:hashrate,{0,0}}]
  use Agent
  def start_link(_) do
    Agent.start_link(fn -> %__MODULE__{} end, name: __MODULE__)
  end

  def set_hashrate(rate,height) do
    Agent.update(__MODULE__, & Map.put(&1,:hashrate,{rate,height}))
  end

  def get_hashrate() do
    Agent.get(__MODULE__, & (Map.fetch!(&1,:hashrate)))
  end
end
