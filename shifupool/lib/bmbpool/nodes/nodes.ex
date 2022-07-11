defmodule Nodes do
  def all() do
    Nodes.GenServer.all_nodes();
  end
  def good() do
    Nodes.GenServer.get_good_nodes();
  end
  def submit(block) when is_binary(block) do
    Nodes.GenServer.submit(block)
  end
  def hashrate() do
    Nodes.Agent.get_hashrate()|>elem(0)
  end
end
