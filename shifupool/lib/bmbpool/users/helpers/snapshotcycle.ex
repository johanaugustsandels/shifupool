defmodule Users.Snapshotcycle do
  def init(length, val \\ 0) do
    now = :os.system_time(:second)
    Stream.cycle([{now, val}]) |> Enum.take(length)
  end

  def cycle(list, current_val) do
    now = :os.system_time(:second)
    {_, list} = List.pop_at(list, 0)
    list ++ [{now, current_val}]
  end

  def rate(list, current_val) do
    if length(list) == 0 do
      0.0
    else
      now = :os.system_time(:second)
      {t0, v0} = List.first(list)
      t1 = now
      v1 = current_val
      if t0 >= t1 || v0 > v1 do
        0.0
      else
        (v1 - v0) / (t1 - t0)
      end
    end
  end
end
