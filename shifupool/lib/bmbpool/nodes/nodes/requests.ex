defmodule Requests do
  defp error_get_string(r) do
    case r do
      :timeout ->
        "timeout"

      a ->
        if is_atom(a) do
          :inet.format_error(a)
        else
          "unknown error"
        end
    end
  end

  def get_balance(host, wallet) do
    url = host <> "/ledger?wallet=" <> wallet

    case HTTPoison.get(url) do
      {:ok, res} ->
        case Jason.decode(res.body) do
          {:ok, parsed} ->
            case parsed do
              %{"balance" => balance} -> {:ok, balance}
              _ -> {:ok, 0}
            end

          _ ->
            {:error, "corrupted json"}
        end

      {:error, %{reason: r}} ->
        {:error, error_get_string(r)}
    end
  end
  def add_transaction_json(host,data) when is_binary(data) do
    case HTTPoison.post(host<>"/add_transaction_json", data) do
      {:ok, res} -> res.body
      {:error, %{reason: r}} ->
        {:error, error_get_string(r)}
    end
  end
end
