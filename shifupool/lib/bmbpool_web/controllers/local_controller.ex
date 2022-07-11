defmodule BmbpoolWeb.LocalController do
  use BmbpoolWeb, :controller

  def work(conn, _args) do
    # blockhash=Base.decode16!(blockhashhex)
    # Poolstate.Mining.set(wallet, blockhash, difficulty)
    # IpRegistry.dispatch_work(blockhash)
    send_resp(conn,200,"")
  end
end
