defmodule Payout do
  defdelegate notify(round), to: Payout.Genserver
  defdelegate job(), to: Payout.Genserver
end
