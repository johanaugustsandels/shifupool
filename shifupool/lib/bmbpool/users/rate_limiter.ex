defmodule RateLimiter do
  @burst 500
  @period :timer.seconds(60)
  @cost @period/@burst
  def new(period \\ @period) do
    System.monotonic_time(:millisecond)-period;
  end
  def next(state,cost \\@cost) when is_number(state) do
    next=max(state,new())+cost
    if next>System.monotonic_time(:millisecond) do
      :error
    else
      {:ok,next}
    end
  end
end
