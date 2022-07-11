ip={3,2,1,3}
name="SDF"
HistoryChart.hashrate(ip,name)



hashrate=[ {1234,132}, {1234,138}, {1234,162}]

hashes=200

now=:os.system_time(:second)
{_,l} = List.pop_at(hashrate,0)
l ++ [{now,hashes}]

hashrate=[ {1234,132}, {1234,138}, {1234,162}]

block=%{ height: 10,
        difficulty: 13,
        hash: "102",
        timestamp: 13213,
        reward: 5
      }
HistoryChart.DB.insert_pastblock(block)
HistoryChart.DB.select_pastblocks(40)

HistoryChart.DB.get_day_blocks(10)
HistoryChart.DB.inc_day_blocks()

{:ok, today} = Date.new(2018, 1, 1)
today.year
today.month

Timex.now |>  Timex.format!("{YYYY}-{0M}-{0D}")


Poolstate.DB.get_owner_payout(0)

Poolstate.DB.insert_owner_payout(0,10,"SDF")
Poolstate.DB.flush()

n=List.first(Application.fetch_env!(:bmbpool, :nodes))

height= HTTPoison.get!("http://54.189.82.240:3000/block_count") |> Map.fetch!(:body)|>Integer.parse()|>elem(0)
lower=max(height-10,2)

history =
for i <- lower..height do
  {:ok,res}=HTTPoison.get("http://54.189.82.240:3000/block/#{i}")
  {:ok,decoded} = res.body|>Jason.decode()
  {decoded["difficulty"], decoded["timestamp"]|>Integer.parse()|>elem(0)}
end
[first|tail]=history
hashes=Enum.reduce(tail,0,fn {diff,_timestamp},sum -> sum+:math.pow(2,diff) end)
time=(List.last(history)|>elem(1))-elem(first,1)
hashes/time


for item <- items do
  
end
#
#
#
# SHA256_Update(&sha256, (unsigned char*)wallet.data(), wallet.size());
# if (!this->isTransactionFee) {
#   wallet = this->fromWallet();
#     SHA256_Update(&sha256, (unsigned char*)wallet.data(), wallet.size());
# }
#   SHA256_Update(&sha256, (unsigned char*)&this->fee, sizeof(TransactionAmount));
#   SHA256_Update(&sha256, (unsigned char*)&this->amount, sizeof(TransactionAmount));
#   SHA256_Update(&sha256, (unsigned char*)&this->timestamp, sizeof(uint64_t));
#
#

# Trying to replicate this https://explorer.0xf10.com/tx/238494a8759c2aed4afe4477153540e4ea61bc314dc25eb3ae8676794873e07d
# hash	238494a8759c2aed4afe4477153540e4ea61bc314dc25eb3ae8676794873e07d
# amount	33.2607
# fee	1
# timestamp	90000
# height	91754
# sender	0008B40BD3669539CBEE12AD8A1C4731E6CE35D6BBB918C4DF
# recipient	00DC371BC0DF3B694F1B57FBCCCDDE0864BA6CA9845DCB73A9
# signature: 2356ED92591AE312D54A3530884F477116CE586F53D2245B0A38C6E10A33F7011C7139DDC1840119B2895EE1A21155EB6130609569DA11E4EB88A2672FCF690E

signature ="2356ED92591AE312D54A3530884F477116CE586F53D2245B0A38C6E10A33F7011C7139DDC1840119B2895EE1A21155EB6130609569DA11E4EB88A2672FCF690E"
from = "0008B40BD3669539CBEE12AD8A1C4731E6CE35D6BBB918C4DF"
to = "00DC371BC0DF3B694F1B57FBCCCDDE0864BA6CA9845DCB73A9"
amount = 332607
fee = 1
timestamp = 90000

json= ~s({"amount":10589918,"fee":0,"from":"00523D9A0212CC9972F16F3203AB6F7287162CE95A97DDCEEB","signature":"87CC9C2841A046FC01F9D5A4BEFB1A5DC1BC25595DA9AA97F8EB0D85A7D9723E1A4532193D5F43E98483A7F0C0620CC0AF5F86C75C349EAE75F8C77C31C5330C","signingKey":"249F75746C2A9587D63656DEEE7C4E1F5762E2829F4F8663ACF653658C942314","timestamp":"0","to":"00BDC02D6A5A44CAAE92C91B77138D7866818E4C323478619C"})
ApiData.Helpers.transaction_hash(json)

Jason.decode!(json)
with {:ok,decoded} <- Jason.decode(json),
     {:ok,to} <- Map.fetch(decoded,"to"),
     {:ok,from} <- Map.fetch(decoded,"from"),
     {:ok,fee} <- Map.fetch(decoded,"fee"),
     {:ok,amount} <- Map.fetch(decoded,"amount"),
     {:ok,timestamp_str} <- Map.fetch(decoded,"timestamp"),
     {timestamp,_} <- Integer.parse(timestamp_str),
     {:ok,signature} <- Map.fetch(decoded,"signature") do
  bin=Base.decode16!(to) <>Base.decode16!(from)<><<fee::little-64,amount::little-64,timestamp::little-64>>
  bin2=:crypto.hash(:sha256,bin)<>Base.decode16!(signature)
  :crypto.hash(:sha256,bin2)|>Base.encode16()
else
  _-> nil
end

{:ok,decoded} = Jason.decode(json)
{:ok,to} = Map.fetch(decoded,"to")
{:ok,from} = Map.fetch(decoded,"from")
{:ok,fee} = Map.fetch(decoded,"fee")
{:ok,amount} = Map.fetch(decoded,"amount")
{:ok,timestamp_str} = Map.fetch(decoded,"timestamp")
{timestamp,_} = Integer.parse(timestamp_str)
{:ok,signature} = Map.fetch(decoded,"signature")


# fn from,to ->  end

# Try with little-endian
bin=Base.decode16!(to) <>Base.decode16!(from)<><<fee::little-64,amount::little-64,timestamp::little-64>>
Base.encode16(bin) # this will be hashed
# "00DC371BC0DF3B694F1B57FBCCCDDE0864BA6CA9845DCB73A90008B40BD3669539CBEE12AD8A1C4731E6CE35D6BBB918C4DF01000000000000003F13050000000000905F010000000000"
:crypto.hash(:sha256,bin)|>Base.encode16()

bin2=:crypto.hash(:sha256,bin)<>Base.decode16!(signature)
:crypto.hash(:sha256,bin2)|>Base.encode16()
# "B58DBB929A751B947242D13B47D7E00125EC0E7B186E4A25E0F439A71D4F8CAD"

# Try with big-endian
bin=Base.decode16!(to) <>Base.decode16!(from)<><<fee::big-unsigned-64,amount::big-unsigned-64,timestamp::big-unsigned-64>>
bin2=:crypto.hash(:sha256,bin)<>Base.decode16!(signature)
:crypto.hash(:sha256,bin2)|>Base.encode16()
Base.encode16(bin) # this will be hashed

# "00DC371BC0DF3B694F1B57FBCCCDDE0864BA6CA9845DCB73A90008B40BD3669539CBEE12AD8A1C4731E6CE35D6BBB918C4DF0000000000000001000000000005133F0000000000015F90"
:crypto.hash(:sha256,bin)|>Base.encode16()
# "A4E6C8E4F9596A7CFECF8156D1F9650926197C07750E7180EC4463DA4CF614A7"

s=:crypto.hash_init(:sha256)
s=:crypto.hash_update(s, Base.decode16!(to))
s=:crypto.hash_update(s, Base.decode16!(from))

s=:crypto.hash_update(s, <<fee::little-64>>)
s=:crypto.hash_update(s, <<amount::little-64>>)
s=:crypto.hash_update(s, <<timestamp::little-64>>)

:crypto.hash_final(s)|>Base.encode16()

Poolstate.DB.recent_payouts()

HTTPoison.post("localhost:4002/pufferfish","SDF")
