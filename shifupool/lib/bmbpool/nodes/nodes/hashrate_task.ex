defmodule Nodes.HashrateTask do
  def start_link(_) do
    Task.start_link(__MODULE__, :hashrate_task,[])
  end
  def child_spec(arg) do
  %{
    id: Stack,
    start: {__MODULE__, :start_link, [arg]}
  }
end

  def hashrate_task() do
    try do
      case Nodes.good()|>elem(1)|>get_hashrate!() do
        :error -> Process.sleep(:timer.seconds(5))
        {hashrate,height} -> 
          IO.puts("Updated hashrate")
          Nodes.Agent.set_hashrate(hashrate,height)
          Process.sleep(:timer.minutes(5))
      end
    rescue
      _ -> 
        Process.sleep(:timer.seconds(5))
    end
    hashrate_task()
  end

  def get_hashrate!(nodes) do
    if length(nodes) > 0 do
      [node | nodes] = nodes

      try do
        height =
          HTTPoison.get!(node <> "/block_count")
          |> Map.fetch!(:body)
          |> Integer.parse()
          |> elem(0)

        lower = max(height - 10, 2)

        history =
          for i <- lower..height do
            {:ok, res} = HTTPoison.get("http://54.189.82.240:3000/block/#{i}")
            {:ok, decoded} = res.body |> Jason.decode()
            {decoded["difficulty"], decoded["timestamp"] |> Integer.parse() |> elem(0)}
          end

        [first | tail] = history
        hashes = Enum.reduce(tail, 0, fn {diff, _timestamp}, sum -> sum + :math.pow(2, diff) end)
        time = (List.last(history) |> elem(1)) - elem(first, 1)
      {hashes / time,height}
      rescue
        _ -> get_hashrate!(nodes)
      end
    else
      :error
    end
  end

  # def start do
  #   
  # end
end
