defmodule BmbpoolWeb.PageController do
  use BmbpoolWeb, :controller

  def index(conn, _params) do
    s = Poolstate.Mining.state()
    # {wallet, hashes, hr30s, hr5m, height} = Poolstate.Mining.get_info()

    params = [
      connections: IpRegistry.total_count(),
      state: s,
      chart: HistoryChart.hashrate("pool"),
      workers: HistoryChart.hashrate("workers")
    ]

    render(conn, "index.html", params)
  end

  def worker(conn,%{"worker" => worker}) when is_binary(worker) do
    with true <- byte_size(worker) <= 50,
         {:ok,mangled} <- Base.decode16(worker),
         [_,worker_name] <- String.split(mangled, ~r{:}, parts: 2)
    do
      IO.inspect(worker_name)
      info=IpRegistry.worker_info(mangled)
      chart=HistoryChart.hashrate(mangled)
      hashrate=
        if is_nil(info) do
          0.0
        else
          info.hashrate
        end
      render(conn,"worker.html",worker_name: worker_name, chart: chart, info: info, hashrate: hashrate)
    else
      _->
        conn
        |> put_status(:not_found)
        |> put_view(BmbpoolWeb.ErrorView)
        |> render(:"404")
    end
  end

  def wallet(conn, %{"wallet" => wallet}) do
    now = System.monotonic_time()
    urounds = Poolstate.lookup_wallet(wallet, false)
    prounds = Poolstate.lookup_wallet(wallet, true)
    {delay, roundend} = Poolstate.Mining.delay_roundend()

    # Poolstate.
    # connection info
    conninfo =
      IpRegistry.lookup(wallet)
      |> Enum.map(fn a -> Task.async(Network.Acceptor, :get_hashinfo, [elem(a, 0)]) end)
      |> Enum.map(fn a -> Task.await(a) end)
      |> Enum.filter(fn a -> a != nil end)
      |> Enum.map(fn info ->
        duration = System.convert_time_unit(now - info.start, :native, :second)

        %{
          hashrate: info.hashrate,
          worker_name: info.worker_name,
          ip: info.ip,
          duration: duration
        }
      end)

    render(conn, "wallet.html",
      delay: delay,
      roundend: roundend,
      wallet: wallet,
      connections: conninfo,
      urounds: urounds,
      prounds: prounds
    )
  end

  def rounds(conn, _params) do
    urounds = Poolstate.DB.unprocessed_rounds()
    prounds = Poolstate.DB.processed_rounds()

    {delay, roundend} = Poolstate.Mining.delay_roundend()

    render(conn, "rounds.html",
      delay: delay,
      roundend: roundend,
      prounds: prounds,
      urounds: urounds
    )
  end

  def round(conn, %{"round" => round}) do
    {r, _} = Integer.parse(round)
    {:ok, participants} = Poolstate.DB.round_participants(r)

    addresses = IpRegistry.addresses()
    active = addresses |> Enum.reduce(MapSet.new(), fn {_, addr}, m -> MapSet.put(m, addr) end)

    total = Enum.reduce(participants, 0, fn [_address, shares, _], acc -> shares + acc end)

    list =
      case total do
        0 ->
          []

        val ->
          for [address, shares, payout] <- participants do
            ratio = shares / val
            isactive = MapSet.member?(active, address)
            {isactive, address, shares, ratio, ratio * 0.95, payout}
          end
      end
    render(conn, "round.html", round: r, list: list, total: total)
  end

  def submitted(conn, _params) do
    f = TruncatedLog.get(:submits)
    render(conn, "log.html", log: f)
  end

  def failed(conn, _params) do
    f = TruncatedLog.get(:failed_requests)
    render(conn, "log.html", log: f)
  end

  def txs(conn, _params) do
    f = TruncatedLog.get(:txs)
    render(conn, "log.html", log: f)
  end
end
