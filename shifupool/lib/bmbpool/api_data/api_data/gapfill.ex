defmodule HistoryChart.Gapfill do
  # def apply(entries) do
  #   interval=30*60 # 30 minutes
  #   floortime = fn timestamp -> Integer.floor_div(timestamp,interval)*interval end
  #   t1=floortime.(:os.system_time(:seconds))
  #   t0=t1-24*60*60
  #   apply(t0,t1,interval,entries)
  # end
  def apply(starttime,endtime,interval,entries) do
    apply_recursive([],starttime,endtime,interval,entries)
  end
  defp apply_recursive(filled,starttime,endtime,interval,entries) do
    {e,{starttime,entries}} = takeone({starttime,entries},interval)
    filled=filled ++ [e]
    if starttime>endtime do
      filled
    else
      apply_recursive(filled,starttime,endtime,interval,entries)
    end
  end
  defp takeone({ta,l},interval) do
    case List.first(l) do
      nil -> 
          {{ta,0.0},{ta+interval,l}}
      [t,hashrate]->
        if t<=ta do
          {_,l}=List.pop_at(l, 0)
          {{t,hashrate},{t+interval,l}}
        else
          {{ta,0.0},{ta+interval,l}}
        end
    end
  end
end
