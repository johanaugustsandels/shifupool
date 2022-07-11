defmodule Backend do
  defp port() do
    Application.fetch_env!(:bmbpool, :backend_port)
  end
  
  def mining_problem(wallet,height,difficulty,reward,lastTimestamp,lastHash) when is_binary(wallet) and is_integer(height) and is_integer(difficulty) and is_integer(reward) and is_integer(lastTimestamp) and is_binary(lastHash) do
    url="http://localhost:#{port()}/problem/#{wallet}/#{height}/#{difficulty}/#{reward}/#{lastTimestamp}/#{lastHash}"
    with {:ok,res} <- HTTPoison.get(url),
         {:ok,dec} <- Jason.decode(res.body),
         %{
           "blockhashhex" => bhex,
         }<- dec
    do
         Base.decode16(bhex)
    else
      _ -> :error
    end
  end

  def pufferfish_hash(content) when is_binary(content) do
    url="http://localhost:#{port()}/pufferfish"
    with {:ok,res} <- HTTPoison.post(url,content),
         {:ok,dec} <- Jason.decode(res.body),
         %{
           "hash" => bhex,
           "zeros" => zeros,
         }<- dec
    do
      %{hash: bhex,
        zeros: zeros}
    else
      _ -> :error
    end
    
  end

  def add_transactions(transaction_data) when is_binary(transaction_data) do
    url="http://localhost:#{port()}/add_transactions"
    with {:ok,res} <- HTTPoison.post(url, transaction_data),
         {:ok,dec} <- Jason.decode(res.body),
         %{
           "blockhashhex" => bhex,
         }<- dec
    do
         Base.decode16(bhex)
    else
      a -> a
      # _ -> :error
    end
  end
  def submit_bytes(nonce,use_pufferfish) when is_binary(nonce) and is_atom(use_pufferfish) do
    url=
      if use_pufferfish do
        "http://localhost:#{port()}/submit_pufferfish/"<>nonce
      else
        "http://localhost:#{port()}/submit/"<>nonce
      end
    IO.inspect(url)
    {:ok,res} = HTTPoison.get(url)
    IO.inspect(res)
      with {:ok,decoded}<-Jason.decode(res.body) do
        case decoded do
          %{"status" => "ok", "hexdump"=>hexdump}->
            Base.decode16(hexdump)
          %{"status" => "INVNONCE"}->
            {:error, :invnonce}
          _ ->
            {:error, :corrupt}
        end
      else
        other->
          IO.inspect(other)
          {:error, :enoent}
      end
  end
  def create_wallet() do
    url="http://localhost:#{port()}/keygen"
    with {:ok,res}<-HTTPoison.get(url),
         {:ok,decoded}<-Jason.decode(res.body) do
      case decoded do
        %{"wallet" => _, "pubKey" => _, "privKey"=>_}->
          {:ok,decoded}
        _ ->
          {:error, :corrupt}
      end
    else
      _->{:error, :enoent}
    end
  end
  def sign_transaction(pubkey,privkey,to,amount,fee,nonce) when is_binary(pubkey) and is_binary(privkey) and is_binary(to) and is_integer(amount) and is_integer(fee) and is_integer(nonce) do
    url="http://localhost:#{port()}/tx/#{pubkey}/#{privkey}/#{to}/#{amount}/#{fee}/#{nonce}"
    with {:ok,res}<-HTTPoison.get(url),
         {:ok,decoded}<-Jason.decode(res.body) do
      case decoded do
        %{"status" => "ok", "transaction"=>transaction}->
          {:ok,transaction}
        _ ->
          {:error, :corrupt}
      end
    else
      _->{:error, :enoent}
    end
  end
end
