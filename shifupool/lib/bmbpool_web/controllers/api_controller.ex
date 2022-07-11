defmodule BmbpoolWeb.ApiController do
  use BmbpoolWeb, :controller

  def lhi_state(conn, _params) do
    s = Poolstate.Mining.state()
    txhashes = Enum.map(Poolstate.recent_payouts(),fn json -> ApiData.Helpers.transaction_hash(json)  end)
    IO.inspect(s)
    connections = IpRegistry.total_count()

    timestamp = System.os_time(:second)
    workerschart =
      (HistoryChart.hashrate("workers")
      |> (Enum.map(&Tuple.to_list(&1))))
      ++ [[timestamp, connections]]
    hashratechart = 
      (HistoryChart.hashrate("pool")
      |> (Enum.map(&Tuple.to_list(&1))))
      ++ [[timestamp, s.hashrate10m]]

    round_blocks=Application.fetch_env!(:bmbpool, :round_blocks)
    res = %{
      config: %{
        poolHost: Application.fetch_env!(:bmbpool, :pool_host),
        ports: [
          %{
            port: Application.fetch_env!(:bmbpool, :pool_port),
            difficulty: 100,
            description: "Low and high end hardware"
          }
        ],
        algirthm: "32nonce_concat_sha256",
        fee: 10 * Application.fetch_env!(:bmbpool, :fee),
        coin: "Bamboo",
        coinUnits: 10000,
        coinDecimalPlaces: 4,
        coinDifficultyTarget: s.difficulty,
        symbol: "BMB",
        finderReward: 0,
        version: "v0.0.2",
        paymentInterval: round_blocks,
        minPaymentThreshold: 2,
        maxPaymentThreshold: 50000*round_blocks,
        transferFee: 1,
        denominationUnit: 10000,
        slushMiningEnabled: false,
        priceCurrency: "USD",
        sendEmails: false,
        blocksChartEnabled: true,
        blocksChartDays: 30,
      },
      lastblock: %{
        difficulty: nil,
        height: nil,
        timestamp: nil,
        hash: nil
      },
      recent_payouts: txhashes,
      network: %{
        hashrate: Nodes.hashrate(),
        hashrateWindow: 10,
        difficulty: s.difficulty,
        height: s.height
      },
      charts: %{
        workers: workerschart,
        pool_hashrate: hashratechart
      },
      pool: %{
        hashrate: s.hashrate10m
      }
    }

    json(conn, res)
  end

  def state(conn, _params) do
    s = Poolstate.Mining.state()
    IO.inspect(s)
    connections = IpRegistry.total_count()

    # """
    # Shifupool stats (see http://185.215.180.7:4001/): 
    # - Hashrate: #{BmbpoolWeb.PageView.format_hashrate(s.hashrate10m)}
    # - Workers: #{connections}
    # - Difficulty: #{s.difficulty}
    # - Height: #{s.height} in round #{s.round}-#{s.round_end}
    # - Wallet: http://ec2-34-218-176-84.us-west-2.compute.amazonaws.com/wallet?host=http://66.252.197.9:3000&id=#{s.wallet}
    res = %{
      hashrate: BmbpoolWeb.PageView.format_hashrate(s.hashrate10m),
      hashrate_raw: s.hashrate10m,
      workers: connections,
      difficulty: s.difficulty,
      height: s.height,
      round_start: s.round,
      round_end: s.round_end,
      wallet: s.wallet
    }

    json(conn, res)
  end

  defp workers(wallet) when is_binary(wallet) do
    now = System.monotonic_time()

    IpRegistry.lookup(wallet)
    |> Enum.map(fn a -> Task.async(Network.Acceptor, :get_hashinfo, [elem(a, 0)]) end)
    |> Enum.map(fn a -> Task.await(a) end)
    |> Enum.filter(fn a -> a != nil end)
    |> Enum.map(fn info ->
      duration = System.convert_time_unit(now - info.start, :native, :second)

      %{
        hashrate: info.hashrate,
        worker_name: info.worker_name,
        ip: :inet.ntoa(info.ip) |> List.to_string(),
        duration: duration
      }
    end)
  end

  defp usershares(wallet) when is_binary(wallet) do
    case List.first(Poolstate.lookup_wallet(wallet, false), nil) do
      [_rbegin, _rend, shares, _total_shares, _reward, _total_reward, _] ->
        shares

      nil ->
        0
    end
  end

  def user(conn, %{"wallet" => wallet}) when is_binary(wallet) do
    s = Poolstate.Mining.state()

    res = %{
      shares: usershares(wallet),
      total_shares: s.total_shares,
      workers: workers(wallet)
    }

    json(conn, res)
  end
end
