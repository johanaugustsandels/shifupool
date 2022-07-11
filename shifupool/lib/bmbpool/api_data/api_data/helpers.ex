defmodule ApiData.Helpers do
  def transaction_hash(json) do
    with {:ok,decoded} <- Jason.decode(json),
         {:ok,to} <- Map.fetch(decoded,"to"),
         {:ok,from} <- Map.fetch(decoded,"from"),
         {:ok,fee} <- Map.fetch(decoded,"fee"),
         {:ok,amount} <- Map.fetch(decoded,"amount"),
         {:ok,timestamp_str} <- Map.fetch(decoded,"timestamp"),
         {timestamp,_} <- Integer.parse(timestamp_str),
         {:ok,signature} <- Map.fetch(decoded,"signature") do
      bin=Base.decode16!(to) <>Base.decode16!(from)<><<fee::little-64,amount::little-64,timestamp::little-64>>
      bin2=:crypto.hash(:sha256,bin)<>Base.decode16!(signature)
      :crypto.hash(:sha256,bin2)|>Base.encode16()|>String.downcase()
    else
      _-> nil
    end
  end
  def transaction_link(json,explorer="https://explorer.0xf10.com/tx/") do
    case transaction_hash(json) do
       nil -> ""
      hash -> explorer<>hash
    end
  end
end
