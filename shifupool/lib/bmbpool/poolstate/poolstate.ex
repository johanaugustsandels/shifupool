defmodule Poolstate do
  def pow_is_fresh(pow) when is_binary(pow) do
    Poolstate.POWSet.is_fresh(pow)
  end
  defdelegate blockhash, to: Poolstate.Mining
  defdelegate state, to: Poolstate.Mining 
  def lookup_wallet(wallet,processed) when is_binary(wallet) do
    {:ok,entries}=Poolstate.DB.lookup_addr(wallet,processed)
    entries
  end
  defdelegate recent_payouts, to: Poolstate.DB

end
