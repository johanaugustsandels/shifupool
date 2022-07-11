defmodule Payout.Task do
  defp work(round) when is_integer(round) do
    [total, wallet, pubkey, privkey] = Poolstate.DB.get_round(round)
    {_height, nodes} = Nodes.good()

    minedlist =
      nodes
      |> Enum.map(fn elem -> Task.async(fn -> Requests.get_balance(elem, wallet) end) end)
      |> Enum.map(fn arg -> Task.await(arg) end)
      |> Enum.filter(fn arg -> elem(arg, 0) == :ok and is_integer(elem(arg, 1)) end)
      |> Enum.map(fn {:ok, balance} -> balance end)

    if length(minedlist) != 0 do
      mined = Enum.min(minedlist)

      shares = Poolstate.DB.get_round_shares(round)
      poolfee = Application.fetch_env!(:bmbpool, :fee)
      div = round(total * (100 / (100 - poolfee)) + 1)

      payouts =
        Enum.map(shares, fn [id, addr, amount] ->
          payout = max(Integer.floor_div(mined * amount, div) - 1, 0)
          {id, addr, payout}
        end)
        |> Enum.filter(fn {_, _, payout} -> payout > 0 end)

      txfee = 1

      {transactions, payoutsum} =
        Enum.map_reduce(payouts, 0, fn {rowid, to, amount}, payoutsum ->
          {:ok, transaction} = Backend.sign_transaction(pubkey, privkey, to, amount, txfee, round)
          json = Jason.encode!(transaction)
          {{rowid, amount, json}, payoutsum + amount + txfee}
        end)

      keep = mined - payoutsum

        if keep > txfee do
          amount=keep - txfee
          {:ok, owntx} =
            Backend.sign_transaction(
              pubkey,
              privkey,
              Application.fetch_env!(:bmbpool, :address),
              amount,
              txfee,
              round
            )
          Poolstate.DB.insert_owner_payout(round,amount,Jason.encode!(owntx))
        end


      Poolstate.DB.insert_transactions(transactions)
      Poolstate.DB.setprocessed_round(mined, round)
      Poolstate.DB.flush()

      {:ok, txs} = Poolstate.DB.round_transactions(round)
      # case Poolstate.DB.get_owner_payout((round) do
      #    nil -> txs
      #   owntx ->[owntx | txs]
      # end

      txt =
        for l <- txs do
          t=List.first(l)
          with false <- is_nil(t),
               {:ok,d} = Jason.decode(t),
               50 = byte_size(d["from"]) do
            d
          else
            _ -> nil
          end
        end|>Enum.filter(fn d -> is_nil(d)==false end)|>Jason.encode!()

      nodes
      |> Enum.map(fn node ->
        Task.async(fn ->
          resbody = Requests.add_transaction_json(node, txt)
          TruncatedLog.log(:txs, "#{node} - #{resbody}")
        end)
      end)
      |> Enum.map(fn arg -> Task.await(arg) end)

      IO.inspect("payout done!")
    end

    :payout_done
  end

  def async(round) when is_integer(round) do
    Task.async(fn -> work(round) end)
  end
end
