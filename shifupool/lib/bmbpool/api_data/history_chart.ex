defmodule HistoryChart do
  alias HistoryChart.Gapfill
  def hashrate(ip, name) when is_tuple(ip) and is_binary(name) do
    m = mangle(ip, name)
    hashrate(m)
  end
  def hashrate(m) when is_binary(m) do
    # 30 minutes
    interval = 30 * 60
    floortime = fn timestamp -> Integer.floor_div(timestamp, interval) * interval end
    t1 = floortime.(:os.system_time(:seconds))
    t0 = t1 - 24 * 60 * 60
    {:ok, history} = HistoryChart.DB.select_hashrate(m, t0, t1)
    Gapfill.apply(t0, t1, interval, history)
  end

  def mangle(ip, name) do
    "#{:inet.ntoa(ip)}:#{name}"
  end
  def pastblocks(n\\ 50) when is_integer(n) do
    {:ok, blocks}=HistoryChart.DB.select_pastblocks(n)
    for [h,d,hash,t,r] <- blocks do
      %{
        height: h,
        difficulty: d,
        hash: hash,
        timestamp: t,
        reward: r
      }
    end
  end
end
