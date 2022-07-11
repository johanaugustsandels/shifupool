defmodule Users.System do
  use Supervisor
  require Logger

  def start_link(_) do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    children = [
      IpRegistry,
      IpBan,
      IpWallet,
      ranch_child_spec(),
    ]
    Supervisor.init(children, strategy: :one_for_one)
  end

  defp ranch_child_spec() do
    port = Application.fetch_env!(:bmbpool, :pool_port)
    Logger.info("Pool listening for incoming connections on port #{port}")
    args = [:tcp_echo, :ranch_tcp, %{socket_opts: [port: port]}, Network.Acceptor, []]

    %{
      id: RanchAcceptor,
      start: {:ranch, :start_listener, args}
    }
  end
  
end
