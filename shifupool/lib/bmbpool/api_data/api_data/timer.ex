defmodule HistoryChart.Timer do
  use GenServer
  # in

  @doc false
  def start_link(_options) do
    GenServer.start_link(__MODULE__, Map.new())
  end

  @impl true
  def handle_info(:wakeup, state) do
    interval = 30 * 60
    floortime = fn timestamp -> Integer.floor_div(timestamp, interval) * interval end
    dbtime=
      case HistoryChart.DB.get_latest_hashratetime() do
        nil -> 0 
        t -> floortime.(t)
      end
    now = :os.system_time(:seconds)
    nowfloor = floortime.(now)
    next = nowfloor + interval

    if nowfloor >= dbtime + interval && now - nowfloor < 5 * 60 do
      timestamp = nowfloor
      snapshot=hashrate_snapshot()
      elems=%{ 
        "pool" => Poolstate.state.hashrate10m,
        "workers" => IpRegistry.total_count()
      }
      elems =
        for {ip, name, hashrate} <- snapshot, name != "", into: elems do
          {HistoryChart.mangle(ip,name), hashrate}
        end

      for {name, hashrate} <- elems do
        HistoryChart.DB.insert_hashrate(name, timestamp, hashrate)
      end
      HistoryChart.DB.flush()
      now = :os.system_time(:seconds)
      seconds = max(next - now, 0)
      Process.send_after(self(), :wakeup, :timer.seconds(seconds))
    else
      seconds = max(next - now, 0)
      Process.send_after(self(), :wakeup, :timer.seconds(seconds))
    end

    {:noreply, state}
  end

  defp hashrate_snapshot do
    for %{hashrate: hr, ip: ip, worker_name: worker_name} <- IpRegistry.hashrate_list(), worker_name != "" do
      {ip,worker_name,hr}
    end
  end

  @impl true
  def init(state) do
    send(self(), :wakeup)
    {:ok, state}
  end
end
