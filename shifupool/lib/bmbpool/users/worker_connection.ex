defmodule WorkerConnection do
  require Logger
  @snapshots 3
  @snapshot_interval 5 * 60

  def snapshot_interval, do: @snapshot_interval

  def init(ip) do
    %{
      ip: ip,
      initialized: false,
      ratelimiter: RateLimiter.new(),
      puffer_ratelimiter: RateLimiter.new(:timer.seconds(11)),
      hashrate_snapshots: Users.Snapshotcycle.init(@snapshots),
      hashes: 0,
      dropped_submissions: 0,
      total_submissions: 0,
      name: "",
      pufferfish_height: Application.fetch_env!(:bmbpool, :pufferfish_height),
      last_job: 0,
      ping: false,
      start: System.monotonic_time()
    }
  end

  def make_hashrate_snapshot(state) do
    c = state.hashrate_snapshots
    %{state | hashrate_snapshots: Users.Snapshotcycle.cycle(c, state.hashes)}
  end

  defp format_dropped(state) do
    (state.dropped_submissions * 100 / state.total_submissions)
    |> Float.round(1)
    |> Float.to_string()
  end

  def process_message(msg, {t, socket} = con, state) when is_binary(msg) do
    # IO.puts("ok " <> msg)
    case Jason.decode(msg) do
      {:ok, parsed} ->
        case parsed do
          %{"pow" => pow, "type" => "Submit"} ->
            process_submit(Base.decode16!(pow), con, state)

          # %{"powPufferfish" => pow, "type" => "Submit"} ->
          #   process_pufferfish(Base.decode16!(pow), con, state)

          # %{"type" => "Debug"} ->
          #   process_debug(con, state)

          %{"type" => "Pong"} ->
            process_pong(con, state)

          %{
            "address" => address,
            "type" => "Initialize",
            "useragent" => useragent
          } ->
            name = Map.get(parsed, "worker_name", "")
            process_init(address, useragent, name, con, state)

          _other ->
            process_unknown(con, state)
        end

      _ ->
        IpBan.ban_by_socket(socket, "malformed JSON", :timer.minutes(1))
        t.shutdown(socket, :read_write)
        state
    end
  end

  defp process_unknown({transport, socket}, state) do
    IpBan.ban_by_socket(socket, "unknown message", :timer.seconds(30))
    transport.send(socket, JsonMessages.notification("Received invalid message") <> "\n")

    if :ok != transport.shutdown(socket, :read_write) do
      transport.close(socket)
    end

    state
  end

  defp process_pong({transport, socket}, state) do
    if state.ping do
      %{state | ping: false}
    else
      transport.send(
        socket,
        JsonMessages.notification("Received unexpected 'Pong' message") <> "\n"
      )

      :ok = transport.shutdown(socket, :read_write)
      state
    end
  end

  defp process_submit(pow, {transport, socket}, %{initialized: false} = state)
       when is_binary(pow) do
    transport.send(
      socket,
      JsonMessages.notification("You submitted before initialization. You are banned.") <>
        "\n"
    )

    IpBan.ban_by_socket(socket, "initialization", :timer.minutes(10))
    :ok = transport.shutdown(socket, :read_write)
    transport.close(socket)
    state
  end

  defp process_submit(pow, {transport, socket}, state) when is_binary(pow) do
    true = state.initialized

    case RateLimiter.next(state.ratelimiter) do
      {:ok, updatedlimiter} ->
        state = %{state | ratelimiter: updatedlimiter}

        case RateLimiter.next(state.puffer_ratelimiter, :timer.seconds(5)) do
          {:ok, updatedlimiter} ->
            state = %{
              state
              | puffer_ratelimiter: updatedlimiter,
                total_submissions: state.total_submissions + 1
            }

            blockhash = Poolstate.Mining.blockhash()

            state =
              with 32 <- byte_size(pow),
                   %{hash: _hash, zeros: zeros} <- Backend.pufferfish_hash(blockhash <> pow),
                   <<d, _::binary>> <- pow do
                if zeros >= d do
                  case Poolstate.Mining.process_valid_share(state.address, pow, d, zeros) do
                    {:ok, balance, value, blocksolved} ->
                      if blocksolved do
                        case Backend.submit_bytes(Base.encode16(pow), true) do
                          {:ok, bytes} ->
                            Logger.info("Submitting block...")
                            Nodes.submit(bytes)

                          {:error, :invnonce} ->
                            nil

                          other ->
                            Logger.error("Cannot submit: #{inspect(other)}")

                            IpRegistry.disconnect_all(
                              "Block generation backend died :( This is a pool bug. You will be disconnected"
                            )
                        end
                      end

                      transport.send(socket, JsonMessages.accept(pow, balance, value) <> "\n")
                      %{state | hashes: state.hashes + value}

                    {:error, :duplicate} ->
                      IpBan.ban_by_socket(socket, "duplicate pow", :timer.minutes(1))

                      transport.send(
                        socket,
                        JsonMessages.notification("Duplicate POW. You are banned for 30 seconds.") <>
                          "\n"
                      )

                      :ok = transport.shutdown(socket, :read_write)
                      state
                  end
                else
                  transport.send(socket, JsonMessages.reject(pow) <> "\n")
                  transport.send(
                    socket,
                    JsonMessages.notification("Debug info: last job was sent #{System.os_time(:second)-state.last_job} seconds ago at timestamp #{state.last_job}.") <>
                      "\n"
                  )
                  state
                end
              else
                _ ->
                  transport.send(socket, JsonMessages.reject(pow) <> "\n")
              end

            # cond do
            #   byte_size(pow) != 32 ->
            #     transport.send(socket, JsonMessages.reject(pow) <> "\n")
            #
            #   %{hash: hash, zeros: zeros} = Backend.pufferfish_hash(blockhash <> pow) ->
            #     <<d, _::binary>> = pow
            #
            #     if d <= zeros do
            #     end
            #
            #     transport.send(
            #       socket,
            #       JsonMessages.accept_pufferfish(pow, d, hash, zeros) <> "\n"
            #     )
            #
            #   true ->
            #     transport.send(socket, JsonMessages.reject(pow) <> "\n")
            # end

            state

          :error ->
            state = %{
              state
              | dropped_submissions: state.dropped_submissions + 1
            }

            transport.send(socket, JsonMessages.reject(pow) <> "\n")

            transport.send(
              socket,
              JsonMessages.notification(
                "Rate limit for pufferfish submissions exceeded. Your submission was dropped. In total #{state.dropped_submissions} of #{state.total_submissions} (~#{format_dropped(state)}%) dropped submissions since connected). "
              ) <>
                "\n"
            )

            state
        end

      :error ->
        IpBan.ban_by_socket(socket, "rate limit", :timer.minutes(1))

        transport.send(
          socket,
          JsonMessages.notification("Rate limit for submissions exceeded. You are banned.") <>
            "\n"
        )

        :ok = transport.shutdown(socket, :read_write)
        state
    end
  end

  # defp process_pufferfish(pow, {transport, socket}, state) when is_binary(pow) do
  #   true = state.initialized
  #
  #   case RateLimiter.next(state.puffer_ratelimiter, :timer.seconds(5)) do
  #     {:ok, updatedlimiter} ->
  #       state = %{state | puffer_ratelimiter: updatedlimiter}
  #       blockhash = Poolstate.Mining.blockhash()
  #
  #       cond do
  #         byte_size(pow) != 32 ->
  #           transport.send(socket, JsonMessages.reject(pow) <> "\n")
  #
  #         %{hash: hash, zeros: zeros} = Backend.pufferfish_hash(blockhash <> pow) ->
  #           <<d, _::binary>> = pow
  #           transport.send(socket, JsonMessages.accept_pufferfish(pow, d, hash, zeros) <> "\n")
  #
  #         true ->
  #           transport.send(socket, JsonMessages.reject(pow) <> "\n")
  #       end
  #
  #       state
  #
  #     :error ->
  #       IpBan.ban_by_socket(socket, "rate limit", :timer.minutes(1))
  #
  #       transport.send(
  #         socket,
  #         JsonMessages.notification("Rate limit for submissions exceeded. You are banned.") <>
  #           "\n"
  #       )
  #
  #       :ok = transport.shutdown(socket, :read_write)
  #       state
  #   end
  # end

  def send_work(blockhash, {transport, socket}, state) do
    algorithm = "PUFFERFISH"
    transport.send(socket, JsonMessages.work(blockhash, algorithm) <> "\n")
    %{state | last_job: System.os_time(:second)}
  end

  def send_message(transport, socket, message) when is_binary(message) do
    transport.send(socket, JsonMessages.notification(message) <> "\n")
  end

  defp process_init(_address, nil, _name, {transport, socket}, state) do
    transport.send(
      socket,
      JsonMessages.notification("This miner is not supported.") <> "\n"
    )

    :ok = transport.shutdown(socket, :read_write)
    state
  end

  defp process_init(address, useragent, name, {transport, socket}, state) do
    if state.initialized == false do
      {:ok, _} = IpRegistry.register_socket(socket)
      {:ok, _} = IpRegistry.register_address(address)
      transport.send(socket, JsonMessages.welcome() <> "\n")
      state=send_work(Poolstate.blockhash(),{transport, socket}, state)
      IpRegistry.register_wallet(address)
      # bad address
      with 50 <- byte_size(address),
           {:ok, _} <- Base.decode16(address) do
        if is_binary(name) && String.length(name) <= 15 && String.printable?(name) do
          case IpWallet.set(state.ip, address) do
            :ok ->
              IO.inspect("Check name #{inspect(name)}")

              if byte_size(name) != 0 do
                {:ok, _} = IpRegistry.register_worker(state.ip, name)
              end

              state
              |> Map.put(:address, address)
              |> Map.put(:useragent, useragent)
              |> Map.put(:worker_name, String.trim(name))
              |> Map.put(:initialized, true)

            {:already_set, addresses} ->
              addressesString = Enum.join(addresses, ", ")

              transport.send(
                socket,
                JsonMessages.notification(
                  "This IP is already connected with the wallet addresses \"#{addressesString}\". You can change your wallet address in the next round"
                ) <> "\n"
              )

              :ok = transport.shutdown(socket, :read_write)
          end
        else
          transport.send(
            socket,
            JsonMessages.notification("You submitted a bad worker name") <> "\n"
          )

          :ok = transport.shutdown(socket, :read_write)
          state
        end
      else
        _ ->
          transport.send(
            socket,
            JsonMessages.notification("You submitted a bad wallet address.") <> "\n"
          )

          :ok = transport.shutdown(socket, :read_write)
          state
      end
    else
      IpBan.ban_by_socket(socket, "duplicate initialize", :timer.hours(1))

      transport.send(
        socket,
        JsonMessages.notification("Duplicate initialize. You are banned.") <> "\n"
      )

      :ok = transport.shutdown(socket, :read_write)
      state
    end
  end

  def hashinfo(state) do
    %{
      start: state.start,
      worker_name: state.worker_name,
      ip: state.ip,
      hashrate: Users.Snapshotcycle.rate(state.hashrate_snapshots, state.hashes)
    }
  end

  def send_ping({transport, socket}, state) do
    transport.send(socket, JsonMessages.ping() <> "\n")
    %{state | ping: true}
  end
end
