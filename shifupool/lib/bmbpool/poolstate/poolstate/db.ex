defmodule Poolstate.DB do
  alias Exqlite.Sqlite3
  use GenServer
  @path "data.db3"

  @doc false
  def start_link(_) do
    GenServer.start_link(__MODULE__, @path, name: __MODULE__)
  end

  @impl true
  def init(path) do
    {:ok, conn} = Exqlite.Sqlite3.open(path)
    Process.send_after(self(), :flush, :timer.seconds(10))

    commands = [
      "CREATE TABLE IF NOT EXISTS `rounds` ( `blockstart` INTEGER, `blockend` INTEGER DEFAULT NULL, `processed` INTEGER DEFAULT 0, `total_shares` INTEGER DEFAULT 0, `total_reward` INTEGER DEFAULT NULL, `wallet` TEXT NOT NULL, `pubkey` TEXT NOT NULL, `privkey` TEXT NOT NULL, PRIMARY KEY(`blockstart`))",
      "CREATE TABLE IF NOT EXISTS `owner_payouts` (`round` INTEGER, `amount` INTEGER, `tx` TEXT, PRIMARY KEY(`round`))",
      "CREATE TABLE IF NOT EXISTS `payouts` ( `address` TEXT, `round` INTEGER, `payout` INTEGER, `shares` INTEGER, `tx` TEXT DEFAULT NULL, `tx_result` TEXT DEFAULT NULL )",
      "CREATE TABLE  IF NOT EXISTS `unpaid` ( `id` INTEGER, PRIMARY KEY(`id`))",
      "CREATE UNIQUE INDEX IF NOT EXISTS `payout_index` ON `payouts` ( `address`, `round`)",
      "CREATE INDEX IF NOT EXISTS `payout_round` ON `payouts` (`round`)",
      "CREATE UNIQUE INDEX IF NOT EXISTS `payoutround_index` ON `payouts` (`round`, tx)",
      "CREATE INDEX IF NOT EXISTS `round_index` ON `rounds` ( `processed` DESC, `blockstart` DESC)",
      "BEGIN TRANSACTION"
    ]

    for c <- commands do
      :ok = Exqlite.Sqlite3.execute(conn, c)
    end

    {:ok, selroundsunprocessed_stmt} =
      Exqlite.Sqlite3.prepare(
        conn,
        "SELECT `blockstart`, `blockend`, `total_shares`, `total_reward`, `wallet`  FROM `rounds` WHERE processed=0 ORDER BY `blockstart` DESC LIMIT 50"
      )

    {:ok, selownerpayout_stmt} =
      Exqlite.Sqlite3.prepare(
        conn,
        "SELECT `tx` FROM `owner_payouts` WHERE round = ?"
      )

    {:ok, insownerpayout_stmt} =
      Exqlite.Sqlite3.prepare(
        conn,
        "INSERT OR IGNORE INTO `owner_payouts` (`round`, `amount`, `tx`) VALUES (?,?,?)"
      )

    {:ok, selroundsprocessed_stmt} =
      Exqlite.Sqlite3.prepare(
        conn,
        "SELECT `blockstart`, `blockend`, `total_shares`, `total_reward`, `wallet`  FROM `rounds` WHERE processed=1 ORDER  BY `blockstart` DESC LIMIT 50"
      )

    {:ok, seladdr_stmt} =
      Exqlite.Sqlite3.prepare(
        conn,
        "SELECT round,blockend,shares,total_shares,payout,total_reward, tx FROM `payouts` JOIN `rounds` ON `payouts`.round=`rounds`.blockstart WHERE `address`=? AND `rounds`.processed=? ORDER BY `round` DESC LIMIT 50"
      )

    {:ok, selroundparticipants_stmt} =
      Exqlite.Sqlite3.prepare(
        conn,
        "SELECT `address`,`shares`, `payout` FROM `payouts` WHERE `round`=?"
      )
    {:ok, selrecentpayouts_stmt} =
      Exqlite.Sqlite3.prepare(
        conn,
        "SELECT `tx` FROM `payouts` WHERE `tx` IS NOT NULL ORDER BY `round` DESC LIMIT ?"
      )
    {:ok, seltx_stmt} =
      Exqlite.Sqlite3.prepare(
        conn,
        "SELECT `tx` FROM `payouts` WHERE `round`=?"
      )

    {:ok, selround_stmt} =
      Exqlite.Sqlite3.prepare(
        conn,
        "SELECT `total_shares`, `wallet`,`pubkey`,`privkey` FROM `rounds` WHERE `blockstart`=?"
      )

    {:ok, selroundshares_stmt} =
      Exqlite.Sqlite3.prepare(
        conn,
        "SELECT `ROWID`, `address`, `shares`  FROM `payouts` WHERE `round`=? AND `tx` IS NULL"
      )

    {:ok, roundadd_stmt} =
      Exqlite.Sqlite3.prepare(
        conn,
        "UPDATE `rounds` SET `total_shares`=`total_shares`+? WHERE `blockstart`=? RETURNING `total_shares`"
      )

    {:ok, payoutsadd_stmt} =
      Exqlite.Sqlite3.prepare(
        conn,
        "UPDATE `payouts` SET shares=shares+? WHERE `address`=? AND `round`=?  RETURNING shares"
      )

    {:ok, ins_stmt} =
      Exqlite.Sqlite3.prepare(
        conn,
        "INSERT INTO `payouts` (`address`, `round`, `payout`, `shares`) VALUES (?,?,0,?)"
      )
    {:ok, setamounttx_stmt} =
      Exqlite.Sqlite3.prepare(
        conn,
        "UPDATE `payouts` SET `payout`=?, `tx`=? WHERE ROWID=?;"
      )

    {:ok, setprocessed_stmt} =
      Exqlite.Sqlite3.prepare(
        conn,
        "UPDATE `rounds` SET `processed`=1, `total_reward`=? WHERE blockstart=?;"
      )

    {:ok, insertunpaid_stmt} =
      Exqlite.Sqlite3.prepare(
        conn,
        "INSERT OR REPLACE INTO `unpaid` (`id`) VALUES (?)"
      )

    {:ok, insround_stmt} =
      Exqlite.Sqlite3.prepare(
        conn,
        "INSERT INTO `rounds` (`blockstart`,`wallet`, `pubkey`, `privkey`) VALUES (?,?,?,?)"
      )

    {:ok, endround_stmt} =
      Exqlite.Sqlite3.prepare(conn, "UPDATE `rounds` SET `blockend`=? WHERE `blockstart`=?")

    {:ok, maxround_stmt} =
      Exqlite.Sqlite3.prepare(
        conn,
        "SELECT `blockstart`,`wallet` FROM `rounds` ORDER BY `blockstart` DESC LIMIT 1;"
      )

    {:ok, firstunprocessed_stmt} =
      Exqlite.Sqlite3.prepare(
        conn,
        "SELECT `blockstart`, `blockend` FROM `rounds` WHERE `processed`=0 ORDER BY blockstart ASC LIMIT 1"
      )

    {:ok,
     %{
       selownerpayout_stmt: selownerpayout_stmt,
       insownerpayout_stmt: insownerpayout_stmt,
       selround_stmt: selround_stmt,
       selroundshares_stmt: selroundshares_stmt,
       selroundsprocessed_stmt: selroundsprocessed_stmt,
       selroundsunprocessed_stmt: selroundsunprocessed_stmt,
       seladdr_stmt: seladdr_stmt,
       selroundparticipants_stmt: selroundparticipants_stmt,
       seltx_stmt: seltx_stmt,
       selrecentpayouts_stmt: selrecentpayouts_stmt,
       payoutsadd_stmt: payoutsadd_stmt,
       roundadd_stmt: roundadd_stmt,
       ins_stmt: ins_stmt,
       setamounttx_stmt: setamounttx_stmt,
       setprocessed_stmt: setprocessed_stmt,
       insertunpaid_stmt: insertunpaid_stmt,
       insround_stmt: insround_stmt,
       maxround_stmt: maxround_stmt,
       firstunprocessed_stmt: firstunprocessed_stmt,
       endround_stmt: endround_stmt,
       conn: conn,
     }}
  end

  @impl true
  def handle_info(:flush, state) do
    :ok = Exqlite.Sqlite3.execute(state.conn, "END TRANSACTION; BEGIN TRANSACTION;")
    Process.send_after(self(), :flush, :timer.seconds(10))
    {:noreply, state}
  end
  @impl true
  def handle_cast({:setprocessed,mined,round},state) when is_integer(mined) and is_integer(round) do
    :ok = Exqlite.Sqlite3.bind(state.conn, state.setprocessed_stmt, [mined, round])
    :done = Sqlite3.step(state.conn, state.setprocessed_stmt)
    {:noreply,state}
  end
  @impl true
  def handle_cast({:insert_transactions,transactions},state) do
    for {rowid,amount,txjson} <- transactions do
    :ok = Exqlite.Sqlite3.bind(state.conn, state.setamounttx_stmt, [amount,txjson,rowid])
    :done = Sqlite3.step(state.conn, state.setamounttx_stmt)
    :ok = Exqlite.Sqlite3.bind(state.conn, state.insertunpaid_stmt, [rowid])
    :done = Sqlite3.step(state.conn, state.insertunpaid_stmt)
    end
    {:noreply,state}
  end

  @impl true
  def handle_cast({:insert_owner_payout,round,amount,txjson},state) do
    stmt=state.insownerpayout_stmt
    :ok = Exqlite.Sqlite3.bind(state.conn, stmt, [round,amount,txjson])
    :done = Sqlite3.step(state.conn, stmt)
    {:noreply,state}
  end

  @impl true
  def handle_cast(:flush,state) do
    :ok = Exqlite.Sqlite3.execute(state.conn, "END TRANSACTION; BEGIN TRANSACTION;")
    {:noreply,state}
  end

  @impl true
  def handle_call(:active_round, _from, state) do
    :ok = Exqlite.Sqlite3.bind(state.conn, state.maxround_stmt, [])

    round =
      case Sqlite3.step(state.conn, state.maxround_stmt) do
        :done ->
          nil

        {:row, [val, wallet]} ->
          :done = Sqlite3.step(state.conn, state.maxround_stmt)
          {val, wallet}
      end

    {:reply, round, state}
  end

  @impl true
  def handle_call(:unprocessed_round, _from, state) do
    :ok = Exqlite.Sqlite3.bind(state.conn, state.firstunprocessed_stmt, [])

    beginend =
      case Sqlite3.step(state.conn, state.firstunprocessed_stmt) do
        :done ->
          nil

        {:row, [begin, roundend]} ->
          if roundend == nil do #ignore rounds which we did not close yet
            nil
          else
            {begin, roundend}
          end
      end
    {:reply, beginend, state}
  end

  @impl true
  def handle_call({:insert_round, round, wallet, pubkey, privkey}, _from, state) do
    :ok = Exqlite.Sqlite3.bind(state.conn, state.insround_stmt, [round, wallet, pubkey, privkey])
    :done = Exqlite.Sqlite3.step(state.conn, state.insround_stmt)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:setend_round, round, endHeight}, _from, state) do
    :ok = Exqlite.Sqlite3.bind(state.conn, state.endround_stmt, [endHeight, round])
    :done = Exqlite.Sqlite3.step(state.conn, state.endround_stmt)
    {:reply, :ok, state}
  end
  @impl true
  def handle_call({:lookup, addr, processed}, _from, state) when is_binary(addr) do
    # :ok = Exqlite.Sqlite3.bind(state.conn, state.add_stmt, [add, round, add, address, round])
    :ok = Exqlite.Sqlite3.bind(state.conn, state.seladdr_stmt, [addr, processed])
    res = Exqlite.Sqlite3.fetch_all(state.conn, state.seladdr_stmt)
    {:reply, res, state}
  end

  @impl true
  def handle_call({:roundparticipants, round}, _from, state) when is_integer(round) do
    # :ok = Exqlite.Sqlite3.bind(state.conn, state.add_stmt, [add, round, add, address, round])
    :ok = Exqlite.Sqlite3.bind(state.conn, state.selroundparticipants_stmt, [round])
    res = Exqlite.Sqlite3.fetch_all(state.conn, state.selroundparticipants_stmt)
    {:reply, res, state}
  end
  @impl true
  def handle_call({:recent_payouts, limit}, _from, state) when is_integer(limit) do
    # :ok = Exqlite.Sqlite3.bind(state.conn, state.add_stmt, [add, round, add, address, round])
    stmt=state.selrecentpayouts_stmt
    :ok = Exqlite.Sqlite3.bind(state.conn,stmt , [limit])
    res = Exqlite.Sqlite3.fetch_all(state.conn, stmt)
    {:reply, res, state}
  end
  @impl true
  def handle_call({:roundtransactions, round}, _from, state) when is_integer(round) do
    # :ok = Exqlite.Sqlite3.bind(state.conn, state.add_stmt, [add, round, add, address, round])
    :ok = Exqlite.Sqlite3.bind(state.conn, state.seltx_stmt, [round])
    res = Exqlite.Sqlite3.fetch_all(state.conn, state.seltx_stmt)
    {:reply, res, state}
  end


  @impl true
  def handle_call({:get_round,round}, _from, state) when is_integer(round) do
    :ok = Exqlite.Sqlite3.bind(state.conn, state.selround_stmt, [round])
    {:ok,res}= Exqlite.Sqlite3.fetch_all(state.conn, state.selround_stmt)
      case res do
        [] -> {:reply,nil,state}
        [res] -> {:reply,res,state}
      end
  end
  @impl true
  def handle_call({:get_round_shares,round}, _from, state) when is_integer(round) do
    :ok = Exqlite.Sqlite3.bind(state.conn, state.selroundshares_stmt, [round])
    {:ok,res}= Exqlite.Sqlite3.fetch_all(state.conn, state.selroundshares_stmt)
    {:reply,res,state}
  end
  @impl true
  def handle_call(:unprocessed_rounds, _from, state) do
    :ok = Exqlite.Sqlite3.bind(state.conn, state.selroundsunprocessed_stmt, [])
    {:ok, entries} = Exqlite.Sqlite3.fetch_all(state.conn, state.selroundsunprocessed_stmt)
    {:reply, entries, state}
  end

  @impl true
  def handle_call(:processed_rounds, _from, state) do
    :ok = Exqlite.Sqlite3.bind(state.conn, state.selroundsprocessed_stmt, [])
    {:ok, entries} = Exqlite.Sqlite3.fetch_all(state.conn, state.selroundsprocessed_stmt)
    {:reply, entries, state}
  end

  @impl true
  def handle_call({:total_shares, round}, _from, state)
      when is_integer(round) do
    :ok = Exqlite.Sqlite3.bind(state.conn, state.roundadd_stmt, [0, round])
    {:row, [total_shares]} = Exqlite.Sqlite3.step(state.conn, state.roundadd_stmt)
    :done = Exqlite.Sqlite3.step(state.conn, state.roundadd_stmt)
    {:reply, total_shares, state}
  end

  @impl true
  def handle_call({:add_shares, round, address, add}, _from, state)
      when is_integer(round) and is_binary(address) and is_integer(add) do
    :ok = Exqlite.Sqlite3.bind(state.conn, state.roundadd_stmt, [add, round])
    {:row, [total_shares]} = Exqlite.Sqlite3.step(state.conn, state.roundadd_stmt)
    :done = Exqlite.Sqlite3.step(state.conn, state.roundadd_stmt)
    :ok = Exqlite.Sqlite3.bind(state.conn, state.payoutsadd_stmt, [add, address, round])

    balance =
      case Exqlite.Sqlite3.step(state.conn, state.payoutsadd_stmt) do
        {:row, [balance]} ->
          :done = Exqlite.Sqlite3.step(state.conn, state.payoutsadd_stmt)
          balance

        :done ->
          :ok = Exqlite.Sqlite3.bind(state.conn, state.ins_stmt, [address, round, add])
          :done = Exqlite.Sqlite3.step(state.conn, state.ins_stmt)
          add
      end

    {:reply, {balance, total_shares}, state}
  end

  @impl true
  def handle_call({:sel_owner_payout,round},_from,state) do
    stmt=state.selownerpayout_stmt
    :ok = Exqlite.Sqlite3.bind(state.conn,stmt,[round])
    case Exqlite.Sqlite3.fetch_all(state.conn, stmt) do
      {:ok,[]} -> {:reply,nil ,state}
      {:ok,[[res]]} -> {:reply,res ,state}
    end
  end

  def add_shares(round, address, add)
      when is_integer(round) and is_binary(address) and is_integer(add) do
    GenServer.call(__MODULE__, {:add_shares, round, address, add})
  end

  def total_shares(nil), do: 0

  def total_shares(round) when is_integer(round) do
    GenServer.call(__MODULE__, {:total_shares, round})
  end

  def insert_round(round, wallet, pubkey, privkey)
      when is_integer(round) and is_binary(wallet) and is_binary(pubkey) and is_binary(privkey) do
    GenServer.call(__MODULE__, {:insert_round, round, wallet, pubkey, privkey})
  end

  def setend_round(round, endHeight) when is_integer(round) do
    GenServer.call(__MODULE__, {:setend_round, round, endHeight})
  end

  def active_round() do
    GenServer.call(__MODULE__, :active_round)
  end

  def lookup_addr(address, true) when is_binary(address) do
    GenServer.call(__MODULE__, {:lookup, address, 1})
  end

  def lookup_addr(address, false) when is_binary(address) do
    GenServer.call(__MODULE__, {:lookup, address, 0})
  end

  def get_round(round) when is_integer(round) do
    GenServer.call(__MODULE__, {:get_round,round})
  end

  def get_round_shares(round) when is_integer(round) do
    GenServer.call(__MODULE__, {:get_round_shares,round})
  end

  def unprocessed_round() do
    GenServer.call(__MODULE__, :unprocessed_round)
  end

  def unprocessed_rounds() do
    GenServer.call(__MODULE__, :unprocessed_rounds)
  end

  def processed_rounds() do
    GenServer.call(__MODULE__, :processed_rounds)
  end

  def insert_transactions(transactions) when is_list(transactions) do
    GenServer.cast(__MODULE__, {:insert_transactions,transactions})
  end
  def setprocessed_round(mined,round) when is_integer(mined) and is_integer(round) do
    GenServer.cast(__MODULE__, {:setprocessed,mined,round})
  end

  def round_participants(round)when is_integer(round) do
    GenServer.call(__MODULE__, {:roundparticipants, round})
  end
  def round_transactions(round)when is_integer(round) do
    GenServer.call(__MODULE__, {:roundtransactions, round})
  end
  def recent_payouts(limit\\100)when is_integer(limit) do
    {:ok,payouts}= GenServer.call(__MODULE__, {:recent_payouts, limit})
    Enum.map(payouts,fn [element] -> element end)
  end
  def flush() do
    GenServer.cast(__MODULE__,:flush)
  end
  def insert_owner_payout(round,amount,transaction) when is_integer(round) and is_integer(amount) and is_binary(transaction) do
    GenServer.cast(__MODULE__, {:insert_owner_payout,round,amount,transaction})
  end
  def get_owner_payout(round) when is_integer(round) do
    GenServer.call(__MODULE__, {:sel_owner_payout,round})
  end
end
