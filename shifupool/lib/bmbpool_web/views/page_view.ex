defmodule BmbpoolWeb.PageView do
  use BmbpoolWeb, :view
  def format_active(b) when is_boolean(b) do
    if b do
      "⏵︎"
    else
      "⏸︎"
    end
  end
  def format_bmb(nil) do
    "NIL"
  end
  def format_bmb(val) when is_integer(val) do
    if val>10000 do
      "#{Float.round(val/10000,3)} BMB"
    else
      "#{val/10} mBMB"
    end
  end
  def format_end(val, roundend) do
    if val==nil do
      roundend-1
    else
      val-1
    end
  end
  def format_hashrate(val) do
    cond do
      val>1000000000 -> "#{val/1000000000|>Float.round(2)}GH/s"
      val>1000000 -> "#{val/1000000|>Float.round(2)}MH/s"
      val>1000 -> "#{val/1000|>Float.round(2)}kH/s"
      true -> "#{round(val)}H/s"
    end
  end
  def bmb(val) do
      "#{val/10000} BMB"
  end
  def format_reward(total_mined) do
    if total_mined==nil do
      "?"
    else
      bmb(total_mined)
    end
  end
  def format_payout(payout,total_mined,shares,total_shares) do
    if total_mined==nil do
      if total_shares==0 do
        "~0%"
      else
        "~#{Float.round(shares*95/total_shares,2)}%"
      end
    else
      bmb(payout)<>" of "<>bmb(total_mined)
    end
  end
  def format_wallet_big(wallet) do
    {:safe,"<code> <a class=\"dim black-70\" href=\"https://explorer.0xf10.com/account/#{wallet}\">#{wallet}</a></code>"}
  end
  def format_wallet(wallet) do
    {:safe,"<code> <a class=\"dim black-70 f6\" href=\"https://explorer.0xf10.com/account/#{wallet}\">#{wallet}</a></code>"}
  end
  def private_address(address) when is_binary(address) do
    (address|>String.slice(0..5))<>"..."
  end
end
