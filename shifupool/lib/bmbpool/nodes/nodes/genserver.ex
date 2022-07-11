defmodule Nodes.GenServer do
  @pollinterval :timer.seconds(2)
  require Logger
  use GenServer

  defp error_get_string(r) do
    case r do
      :timeout ->
        "timeout"

      a ->
        if is_atom(a) do
          :inet.format_error(a)
        else
          "unknown error"
        end
    end
  end

  defp request_submit(nodes, data) do
    Enum.map(nodes, fn node ->
      Task.start_link(fn ->
        url = node <> "/submit"

        case HTTPoison.post(url, data, [{"Content-Type", "application/octet-stream"}]) do
          {:error, %{reason: r}} ->
            errstr = error_get_string(r)
            TruncatedLog.log(:failed_requests, "#{url} - #{errstr}")

          {:ok, response} ->
            TruncatedLog.log(:submits, "#{url} - #{response.body}")
        end
      end)
    end)
  end

  defp request_mine(nodes) do
    Enum.map(nodes, fn node ->
      Task.start_link(fn ->
        url = node <> "/mine"

        case HTTPoison.get(url) do
          {:error, %{reason: r}} ->
            errstr = error_get_string(r)
            TruncatedLog.log(:failed_requests, "#{url} - #{errstr}")

          {:ok, res} ->
            with {:ok, decoded} <- Jason.decode(res.body),
                 %{
                   "chainLength" => length,
                   "miningFee" => reward,
                   "challengeSize" => difficulty,
                   "lastHash" => lastHash,
                   "lastTimestamp" => lastTimestamp
                 } <- decoded,
                 {timestamp, ""} <- Integer.parse(lastTimestamp) do
              msg = %{
                chainLength: length,
                reward: reward,
                difficulty: difficulty,
                lastHash: lastHash,
                lastTimestamp: timestamp
              }

              GenServer.cast(__MODULE__, {:mine_result, msg, node})
            else
              _ ->
                errstr = "no json or wrong structure"
                TruncatedLog.log(:failed_requests, "#{url} - #{errstr}")
            end
        end
      end)
    end)
  end

  @doc false
  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def handle_call(:get_good_nodes, _from, state) do
    {:reply, {state.chainLength, state.good_nodes}, state}
  end

  @impl true
  def handle_call(:all_nodes, _from, state) do
    {:reply, state.nodes, state}
  end

  @impl true
  def handle_cast({:set_nodes, nodes}, state) do
    {:noreply, %{state | nodes: nodes}}
  end

  @impl true
  def handle_cast({:mine_result, msg, node}, state) do
    length = msg.chainLength

    state =
      if state.chainLength < length do
        height = length + 1

        Poolstate.Mining.new_height(
          height,
          msg.difficulty,
          msg.reward,
          msg.lastTimestamp,
          msg.lastHash
        )

        %{state | chainLength: length, good_nodes: MapSet.new([node])}
      else
        if state.chainLength == length do
          %{state | good_nodes: MapSet.put(state.good_nodes, node)}
        else
          state
        end
      end

    {:noreply, state}
  end

  @impl true
  def handle_cast({:submit, data}, state) do
    request_submit(state.nodes, data)
    {:noreply, state}
  end

  @impl true
  def handle_info(:pullwork, state) do
    Process.send_after(self(), :pullwork, @pollinterval)
    request_mine(state.nodes)
    {:noreply, state}
  end

  @impl true
  def init(_) do
    state = %{
      nodes: Application.fetch_env!(:bmbpool, :nodes),
      good_nodes: MapSet.new(),
      chainLength: 0
    }
    Logger.info("Network nodes are #{inspect(state.nodes)}")

    Process.send_after(self(), :pullwork, :timer.minutes(0))
    {:ok, state}
  end

  def set_nodes(nodes) when is_list(nodes) do
    # GenServer.cast(__MODULE__, {:set_nodes, nodes}) # use fixed nodes set for now
    :ok
  end

  def all_nodes() do
    GenServer.call(__MODULE__, :all_nodes)
  end

  def get_good_nodes() do
    {length, mapset} = GenServer.call(__MODULE__, :get_good_nodes)
    {length, MapSet.to_list(mapset)}
  end

  # Requests
  def submit(b) do
    GenServer.cast(__MODULE__, {:submit, b})
  end
end
