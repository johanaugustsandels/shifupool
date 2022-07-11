defmodule IpRegistry do
  def start_link(_val) do
    Registry.start_link(keys: :duplicate, name: __MODULE__)
  end

  def child_spec(val) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [val]},
      type: :supervisor
    }
  end

  def register_address(address) do
    Registry.register(__MODULE__, :address, address)
  end

  def register_socket(socket) do
    Registry.register(__MODULE__, :socket, socket)
  end

  def register_ip(ip) do
    Registry.register(__MODULE__, ip, nil)
  end

  def register_worker(ip,name) do
    m = HistoryChart.mangle(ip,name) 
    Registry.register(__MODULE__, m, nil)
  end

  def worker_info(mangled) do
    case List.first(lookup(mangled)) do
      nil -> nil
      {pid,_info} -> Network.Acceptor.get_hashinfo(pid)
    end
  end

  def register_wallet(wallet) when is_binary(wallet) do
    Registry.register(__MODULE__, wallet, nil)
  end

  def count(ip) do
    Registry.count_match(__MODULE__, ip, :_)
  end

  def total_count() do
    Registry.count_match(__MODULE__, :socket, :_)
  end

  def addresses() do
    Registry.lookup(__MODULE__, :address)
  end

  def dispatch_work(blockhash) do
    Registry.dispatch(__MODULE__, :socket, fn entries ->
      for {pid, socket} <- entries, do: Network.Acceptor.send_work(pid, socket, blockhash)
    end)
  end

  def hashrate_list do
    Registry.select(__MODULE__, [
      {{:socket, :"$1", :_}, [], [:"$1"]}
    ])
    |> Enum.map(fn pid ->
      Task.async(fn -> Network.Acceptor.get_hashinfo(pid) end)
    end)
    |> Enum.map(fn t -> Task.await(t) end)
  end

  def disconnect_all(message) when is_binary(message) do
    Registry.dispatch(__MODULE__, :socket, fn entries ->
      for {pid, socket} <- entries, do: Network.Acceptor.close_connection(pid, socket, message)
    end)
  end

  def lookup(key) do
    Registry.lookup(__MODULE__, key)
  end

  def all() do
    Registry.select(__MODULE__, [
      {{:"$1", :"$2", :"$3"}, [], [%{key: :"$1", pid: :"$2", value: :"$3"}]}
    ])
  end
end
