defmodule IpBan do
  require Cachex.Spec

  def start_link(_) do
    Cachex.start_link(__MODULE__,
      expiration:
        Cachex.Spec.expiration(
          default: :timer.seconds(30),
          interval: :timer.seconds(30),
          lazy: true
        )
    )
  end

  def child_spec(arg) do
    %{id: __MODULE__, start: {__MODULE__, :start_link, [arg]}, type: :supervisor}
  end

  def ban_time(ip) do
    Cachex.ttl(__MODULE__, ip)
  end

  def ban_by_socket(socket, reason, ttl \\ :timer.seconds(30)) do
    case :inet.peername(socket) do
      {:ok, {ip, _}} ->
        ban(ip,reason, ttl)
      _ -> nil
    end
  end
  def ban(ip, reason, ttl \\ :timer.seconds(30)) do
    IO.puts("banned #{inspect(ip)}, reason: #{reason}")
    Cachex.put(__MODULE__, ip, nil, ttl: ttl)
  end
end
