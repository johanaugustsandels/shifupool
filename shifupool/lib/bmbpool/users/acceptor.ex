defmodule Network.Acceptor do
  use GenServer
  require Logger

  defp transport_socket(state) do
    {elem(state, 1),elem(state, 6)}
  end
  defp connection_state(state) do
    elem(state, 4)
  end
  defp put_connection_state(state,setto) do
    put_elem(state, 4,setto)
  end

  defp shutdown(socket, message, state) do
    transport = elem(state, 1)
    WorkerConnection.send_message(transport, socket, message)
    transport.shutdown(socket, :read_write)
  end

  @doc false
  def start_link(ref, transport, opts) do
    GenServer.start_link(__MODULE__, {ref, transport, opts})
  end

  @impl true
  def init(args) do
    {:ok, nil, {:continue, args}}
  end

  @impl true
  def handle_call(:get_hashinfo, _from, state) do
    constate = connection_state(state)
    {:reply, WorkerConnection.hashinfo(constate), state}
  end

  @impl true
  def handle_info(msg, {_ref, transport, _opts, messages, connectionState, timer, socket} = state) do
    {ok, closed, error, _passive} = messages

    case msg do
      :ping ->

        state =
          state
          |> put_elem(5, Process.send_after(self(), :expire, :timer.seconds(20)))
          |> put_elem(4, WorkerConnection.send_ping({transport, socket}, connectionState))

        {:noreply, state}

      :hashrate_snapshot ->
        state = state |> put_elem(4, WorkerConnection.make_hashrate_snapshot(connectionState))

        Process.send_after(
          self(),
          :hashrate_snapshot,
          :timer.seconds(WorkerConnection.snapshot_interval())
        )

        {:noreply, state}

      :expire ->
        shutdown(socket, "Pool did not receive messages", state)
        {:noreply, state}

      {^ok, socket, data} ->
        Process.cancel_timer(timer)

        state =
          state
          |> put_elem(5, Process.send_after(self(), :ping, :timer.minutes(3)))
          |> put_elem(4, WorkerConnection.process_message(data, {transport, socket}, connectionState))

        transport.setopts(socket, active: :once)
        {:noreply, state}

      {^closed, _socket} ->
        {:stop, :normal, state}

      {^error, socket, reason} ->
        transport.setopts(socket, active: :once)
        IO.inspect("WorkerConnection error: #{inspect(reason)}")
        {:noreply, state}

      other ->
        IO.puts("other:")
        IO.inspect(other)
        {:noreply, state}
    end
  end

  @impl true
  def handle_info(msg, state) do
    IO.puts("handle_info 2")
    IO.inspect(msg)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:send_work, _socket, blockhash}, state) do
    # transport = elem(state, 1)
    
    {:noreply, 
      put_connection_state(state,WorkerConnection.send_work(blockhash,
        transport_socket(state),
        connection_state(state)))
      }
  end

  @impl true
  def handle_cast({:close, socket, message}, state) do
    shutdown(socket, message, state)
    {:noreply, state}
  end

  @impl true
  def handle_continue({ref, transport, opts}, _state) do
    {:ok, socket} = :ranch.handshake(ref)

    case :inet.peername(socket) do
      {:ok, {ip, _}} ->
        timer = Process.send_after(self(), :expire, :timer.seconds(3))
        transport.setopts(socket, active: :once, packet: :line)
        messages = {_ok, _closed, _error, _passive} = transport.messages()
        cs = WorkerConnection.init(ip)

        Process.send_after(
          self(),
          :hashrate_snapshot,
          :timer.seconds(WorkerConnection.snapshot_interval())
        )

        c = IpRegistry.count(ip)

        if c < 10 do
          case IpBan.ban_time(ip) do
            {:ok, nil} ->
              {:ok, _} = IpRegistry.register_ip(ip)

            {:ok, ms} ->
              transport.send(socket, JsonMessages.welcome() <> "\n")

              transport.send(
                socket,
                JsonMessages.notification("You were banned. Wait #{round(ms / 1000)} seconds.") <>
                  "\n"
              )

              transport.shutdown(socket, :read_write)
          end
        else
          IO.puts("Rejected connection from #{inspect(ip)}")
          transport.send(socket, JsonMessages.welcome() <> "\n")

          transport.send(
            socket,
            JsonMessages.notification(
              "Too many connections from this IP. You will be disconnected."
            ) <>
              "\n"
          )

          transport.shutdown(socket, :read_write)
        end

        {:noreply, {ref, transport, opts, messages, cs, timer, socket}}

      _ ->
        {:stop, :shutdown, ref}
    end
  end

  def send_work(pid, socket, blockhash) when is_binary(blockhash) do
    GenServer.cast(pid, {:send_work, socket, blockhash})
  end

  def close_connection(pid, socket, message) when is_binary(message) do
    GenServer.cast(pid, {:close, socket, message})
  end

  def get_hashinfo(pid) do
    try do
      GenServer.call(pid, :get_hashinfo)
    catch
      :exit, _ -> nil
    end
  end
end
