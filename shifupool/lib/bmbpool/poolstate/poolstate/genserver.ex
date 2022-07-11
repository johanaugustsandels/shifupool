defmodule Poolstate.Mining do
  @snapshots 3
  use Bitwise
  alias Poolstate.DB
  alias Poolstate.POWSet
  use GenServer

  defstruct [
    :wallet,
    :wallet_balance,
    :wallet_balance_height,
    :difficulty,
    :blockhash,
    :height,
    :powset,
    :round_blocks,
    :payout_delay,
    :round,
    :round_end,
    :unprocessed_round,
    :total_shares,
    :hashes,
    :hashrate_snapshots,
    :hashesBlock,
    :hashrate10m
  ]

  defp insert_round(roundstart) when is_integer(roundstart) do
    {:ok, keys} = Backend.create_wallet()
    wallet = Map.fetch!(keys, "wallet")
    DB.insert_round(roundstart, wallet, Map.fetch!(keys, "pubKey"), Map.fetch!(keys, "privKey"))
    wallet
  end

  defp newround_check(state) do
    round_blocks = state.round_blocks
    roundstart = round_blocks * Integer.floor_div(state.height-1, round_blocks)

    cond do
      state.round == nil ->
        IpWallet.reset()
        IO.puts("Starting initial round #{roundstart}")
        # start new round in db
        wallet = insert_round(roundstart)

        %__MODULE__{
          state
          | wallet: wallet,
            round_blocks: round_blocks,
            wallet_balance: -1,
            wallet_balance_height: 0,
            round: roundstart,
            round_end: roundstart + round_blocks
        }

      state.round < roundstart ->
        IpWallet.reset()
        roundend = round_blocks * (1 + Integer.floor_div(state.round, round_blocks))
        # end round in db
        DB.setend_round(state.round, roundend)
        # start new round in db
        wallet = insert_round(roundstart)
        IO.puts("Starting new round #{roundstart}")

        %__MODULE__{
          state
          | wallet: wallet,
            wallet_balance: -1,
            wallet_balance_height: 0,
            round: roundstart,
            round_end: roundstart + round_blocks,
            unprocessed_round: DB.unprocessed_round(),
            total_shares: 0
        }

      true ->
        state
    end
  end

  defp roundprocessing_check(state) do
    IO.puts("roundprocessing_check #{inspect(state.unprocessed_round)}")

    case state.unprocessed_round do
      {round, roundend} ->
        if roundend + state.payout_delay <= state.height do
          Payout.notify(round)
        end

        state

      nil ->
        state
    end
  end

  defp hashstate(%{hashes: hashes}) do
    %{
      hashes: hashes,
      time: System.monotonic_time(:millisecond)
    }
  end

  @doc false
  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    round_blocks = Application.fetch_env!(:bmbpool, :round_blocks)

    r =
      case DB.active_round() do
        nil ->
          %{round: nil, rend: 0, total_shares: 0, wallet: "NOT INITIALIZED"}

        {round, wallet} ->
          %{
            round: round,
            rend: round_blocks * (1 + Integer.floor_div(round, round_blocks)),
            total_shares: DB.total_shares(round),
            wallet: wallet
          }
      end

    state = %__MODULE__{
      wallet: r.wallet,
      wallet_balance: -1,
      wallet_balance_height: 0,
      difficulty: nil,
      blockhash: "",
      height: 0,
      powset: MapSet.new(),
      round_blocks: round_blocks,
      payout_delay: Application.fetch_env!(:bmbpool, :payoutdelay_blocks),
      round: r.round,
      round_end: r.rend,
      unprocessed_round: DB.unprocessed_round(),
      total_shares: r.total_shares,
      hashes: 0,
      hashrate_snapshots: Users.Snapshotcycle.init(@snapshots),
      hashesBlock: 0,
      hashrate10m: 0
    }

    IO.inspect("Total shares: #{state.total_shares}")

    {:ok, state, {:continue, :init}}
  end

  @impl true
  def handle_continue(:init, state) do

    Process.send_after(self(), :"4m", :timer.minutes(4))
    Process.send_after(self(), {:"10m", hashstate(state)}, :timer.minutes(10))
    Process.send_after(self(), :request_balance, :timer.seconds(30))
    {:noreply, state}
  end

  #
  @impl true
  def handle_info({:"10m", hashstate}, state) do
    Process.send_after(self(), {:"10m", hashstate(state)}, :timer.minutes(10))

    {:noreply,
     %__MODULE__{
       state
       | hashrate10m:
           (state.hashes - hashstate.hashes) *
             (1000 / (System.monotonic_time(:millisecond) - hashstate.time))
     }}
  end

  @impl true
  def handle_info(:"4m", state) do
    Process.send_after(self(), :"4m", :timer.minutes(4))

    {:noreply,
     %__MODULE__{
       state
       | hashrate_snapshots: Users.Snapshotcycle.cycle(state.hashrate_snapshots,state.hashes)
     }}
  end

  @impl true
  def handle_info(:request_balance, state) do
    Process.send_after(self(), :request_balance, :timer.seconds(30))

    fn ->
      {height, nodes} = Nodes.good()

      vals =
        nodes
        |> Enum.map(fn node -> Task.async(fn -> Requests.get_balance(node, state.wallet) end) end)
        |> Enum.map(fn t -> Task.await(t) end)
        |> Enum.filter(fn res -> elem(res, 0) == :ok and is_integer(elem(res, 1)) end)
        |> Enum.map(fn {:ok, balance} -> balance end)

      if length(vals) != 0 do
        balance = Enum.min(vals)
        GenServer.cast(__MODULE__, {:balance_msg, height, state.wallet, balance})
      end
    end

    {:noreply, state}
  end

  @impl true
  def handle_cast({:balance_msg, height, wallet, balance}, state) do
    if state.wallet_balance_height < height and state.wallet == wallet do
      {:noreply, %__MODULE__{state | wallet_balance: balance, wallet_balance_height: height}}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_cast(:notify_processed_block, state) do
    state =
      %__MODULE__{state | unprocessed_round: DB.unprocessed_round()}
      |> roundprocessing_check()

    {:noreply, state}
  end

  @impl true
  def handle_cast({:transaction_data, txdata}, state) do
    state =
      case Backend.add_transactions(txdata) do
        {:ok, blockhash} ->
          if blockhash != state.blockhash do
            IpRegistry.dispatch_work(blockhash)
            %__MODULE__{state | blockhash: blockhash}
          else
            state
          end

        _ ->
          IpRegistry.disconnect_all("Pool has no work :( Shifu is dead. You are disconnected...")
          state
      end

    {:noreply, state}
  end

  @impl true
  def handle_cast(
        {:new_height, height, difficulty, reward, lastTimestamp, lastHash},
        state
      ) do
    POWSet.reset()

    state =
      %{state | difficulty: difficulty, height: height, powset: MapSet.new(), hashesBlock: 0}
      |> newround_check()
      |> roundprocessing_check()

    state =
      case Backend.mining_problem(
             state.wallet,
             height,
             difficulty,
             reward,
             lastTimestamp,
             lastHash
           ) do
        {:ok, blockhash} ->
          IpRegistry.dispatch_work(blockhash)
          %__MODULE__{state | blockhash: blockhash}

        _ ->
          IpRegistry.disconnect_all("Pool has no work :( Shifu is dead. You are disconnected...")
          state
      end

    #########################
    # now request transactions
    {_height, nodes} = Nodes.good()

    t =
      Task.async(fn ->
        nodes
        |> Enum.map(fn node ->
          Task.async(fn ->
            url = node <> "/gettx"
            HTTPoison.get(url)
          end)
        end)

        # wait for the fasterst response of good nodes
        receive do
          {_ref, {:ok, res}} -> {:ok, res}
        end
      end)

    case Task.yield(t) do
      {:ok, {:ok, res}} ->
        txdata = res.body
        GenServer.cast(__MODULE__, {:transaction_data, txdata})

      _ ->
        Task.shutdown(t, :brutal_kill)
    end

    {:noreply, state}
  end

  defp add_valid_share(address,pow,share_difficulty,zeros,state) do
        if MapSet.member?(state.powset, pow) && share_difficulty < 60 do
          {{:error,:duplicate},state}
        else
          # new pow
          value = 1 <<< share_difficulty

          difficulty = state.difficulty
          solved = zeros >= difficulty

          state = %__MODULE__{
            state
            | hashes: state.hashes + value,
              hashesBlock: state.hashesBlock + value,
              powset: MapSet.put(state.powset, pow)
          }

          # make this async
          {balance, total} = Poolstate.DB.add_shares(state.round, address, value)
          {{:ok,balance,value,solved},%__MODULE__{state | total_shares: total}}
        end
  end

  @impl true
  def handle_call({:add_valid_share,{address,pow,share_difficulty,zeros}},_from, state) do
    {res,state}=add_valid_share(address,pow,share_difficulty,zeros,state)
    {:reply,res,state}
  end

  @impl true
  def handle_call({:check_pow, address, pow}, _from, state)
      when is_binary(address) and is_binary(pow) do
    blockhash = state.blockhash

    case Work.validate_share(blockhash, pow) do
      {true, share_difficulty, z} ->
        {res,state}=add_valid_share(address,pow,share_difficulty,z,state)
        {:reply,res,state}

      _ ->
        {:reply, {:error, :invalid}, state}
    end
  end

  # @impl true
  # def handle_call({:check_pow, address, pow}, _from, state)
  #     when is_binary(address) and is_binary(pow) do
  #   blockhash = state.blockhash
  #   difficulty = state.difficulty
  #
  #   case Work.validate_share(blockhash, pow) do
  #     {true, share_difficulty, z} ->
  #       solved = z >= difficulty
  #
  #       if MapSet.member?(state.powset, pow) && share_difficulty < 60 do
  #         {:reply, {:error, :duplicate}, state}
  #       else
  #         # new pow
  #         value = 1 <<< share_difficulty
  #
  #         state = %__MODULE__{
  #           state
  #           | hashes: state.hashes + value,
  #             hashesBlock: state.hashesBlock + value,
  #             powset: MapSet.put(state.powset, pow)
  #         }
  #
  #         # make this async
  #         {balance, total} = Poolstate.DB.add_shares(state.round, address, value)
  #         {:reply, {:ok, balance, value, solved}, %__MODULE__{state | total_shares: total}}
  #       end
  #
  #     _ ->
  #       {:reply, {:error, :invalid}, state}
  #   end
  # end

  @impl true
  def handle_call(:blockhash, _from, state) do
    {:reply, state.blockhash, state}
  end

  @impl true
  def handle_call(:height, _from, state) do
    {:reply, state.height, state}
  end

  @impl true
  def handle_call(:roundend, _from, state) do
    {:reply, {state.payout_delay, state.round_end}, state}
  end

  @impl true
  def handle_call(:state, _from, state) do
    result =
      Map.take(
        state,
        [
          :round,
          :round_end,
          :total_shares,
          :wallet,
          :height,
          :difficulty,
          :hashesBlock,
          # :hashrate10m
        ]
      )|>Map.put(:hashrate10m,Users.Snapshotcycle.rate(state.hashrate_snapshots,state.hashes))

    {:reply, result, state}
  end

  def check_pow(address, pow) when is_binary(address) and is_binary(pow) do
    GenServer.call(__MODULE__, {:check_pow, address, pow})
  end

  def process_valid_share(address,pow,share_difficulty,zeros) when is_binary(address) and is_binary(pow) and is_integer(share_difficulty) and is_integer(zeros) do
    GenServer.call(__MODULE__, {:add_valid_share,{address,pow,share_difficulty,zeros}})
  end

  def blockhash() do
    GenServer.call(__MODULE__, :blockhash)
  end

  def height() do
    GenServer.call(__MODULE__, :height)
  end

  def state() do
    GenServer.call(__MODULE__, :state)
  end

  def new_height(height, difficulty, reward, lastTimestamp, lastHash)
      when is_integer(height) and is_integer(difficulty) and is_integer(reward) and
             is_integer(lastTimestamp) and is_binary(lastHash) do
    GenServer.cast(__MODULE__, {:new_height, height, difficulty, reward, lastTimestamp, lastHash})
  end

  def notify_processed_block() do
    GenServer.cast(__MODULE__, :notify_processed_block)
  end

  def delay_roundend do
    GenServer.call(__MODULE__, :roundend)
  end
end
