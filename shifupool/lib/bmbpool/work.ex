defmodule Work do
  use Bitwise

  def validate_share(problem, share) when is_binary(share) do
    if byte_size(share) == 32 do
      z =
        :crypto.hash(:sha256, problem <> share)
        |> zeros()
      <<d,_::binary>>=share
      {z >= d,d,z}
    else
      {false,nil}
    end
  end

  def zeros(a, b \\ 0) when is_binary(a) do
    case a do
      <<0, r::binary>> ->
        zeros(r, b + 8)

      <<byte, _r::binary>> ->
        zeros_byte(byte, b)
    end
  end

  defp zeros_byte(byte, z) do
    if byte < 128 do
      zeros_byte(byte <<< 1, z + 1)
    else
      z
    end
  end
end
