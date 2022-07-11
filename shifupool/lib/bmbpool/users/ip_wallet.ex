defmodule IpWallet do
  # This module exists to limit the amount of wallets that can be created from one IP.
  use Agent
  @walletlimit 3

  def start_link(_) do
    Agent.start_link(fn -> Map.new() end, name: __MODULE__)
  end

  def set(ip, address) do
    Agent.get_and_update(
      __MODULE__,
      fn state ->
        {returnval, newstate} =
          case Map.get(state, ip, nil) do
            # not present in map
            nil ->
              {:ok, Map.put(state, ip, MapSet.new([address]))}

            # present in map
            mapset ->
              if MapSet.size(mapset) >= @walletlimit do
                if MapSet.member?(mapset, address) do
                  {:ok, state}
                else
                  {{:already_set, MapSet.to_list(mapset)}, state}
                end
              else
                {:ok, put_in(state, [ip], MapSet.put(mapset, address))}
              end
          end

        # last expression is return value of this local function
        # get_and_update returns the first element of the tuple to the caller
        # and takes the second element as the new state
        {returnval, newstate}
      end
    )
  end

  def reset do
    Agent.update(__MODULE__, fn _state -> Map.new() end)
  end
end
