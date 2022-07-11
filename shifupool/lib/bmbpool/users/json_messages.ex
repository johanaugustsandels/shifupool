defmodule JsonMessages do
  use Bitwise
  def notification(str) when is_binary(str) do
    %{
      type: "Notification",
      msg: str
    }|>Jason.encode!
  end
  def ping() do
    %{
      type: "Ping",
    }
    |>Jason.encode!
  end
  def discard_work() do
    %{
      type: "Job",
    }
    |>Jason.encode!
  end
  def work(blockhash,algorithm) when is_binary(blockhash) and is_binary(algorithm) do
    %{
      type: "Work",
      algorithm: algorithm,
      blockhash: Base.encode16(blockhash),
    }
    |>Jason.encode!
  end
  def reject(pow) when is_binary(pow) do
    %{
      type: "Reject",
      POW: Base.encode16(pow),
    }
    |>Jason.encode!
  end
  def accept_pufferfish(pow,shares,hash,zeros) when is_binary(pow) do
    %{
      type: "DebugPufferfish",
      POW: Base.encode16(pow),
      shares: shares,
      pufferfish_hash: hash,
      accept: shares <= (1 <<< zeros),
      zeros: zeros
    }
    |>Jason.encode!
  end
  def accept(pow,newbalance,add) when is_binary(pow) do
    %{
      type: "Accept",
      POW: Base.encode16(pow),
      newbalance: newbalance,
      add: add,
    }
    |>Jason.encode!
  end
  def welcome() do
    notification("Hi there! This is shifupool.")
  end
end
