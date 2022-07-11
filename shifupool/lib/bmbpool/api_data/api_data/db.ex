defmodule HistoryChart.DB do
  alias Exqlite.Sqlite3
  use GenServer
  @path "hashrate_history.db3"

  @doc false
  def start_link(_) do
    GenServer.start_link(__MODULE__, @path, name: __MODULE__)
  end

  @impl true
  def init(path) do
    {:ok, conn} = Exqlite.Sqlite3.open(path)
    Process.send_after(self(), :flush, :timer.seconds(10))

    commands = [
      "CREATE TABLE IF NOT EXISTS `worker_hashrate` ( `name` INTEGER, `hashrate` INTEGER, `timestamp` INTEGER)",
      "CREATE TABLE IF NOT EXISTS `hashrate_times` (`timestamp` INTEGER, PRIMARY KEY(`timestamp`))",
      "CREATE TABLE IF NOT EXISTS `day_blocks` ( `date` TEXT UNIQUE, `blocks` INTEGER)",
      "CREATE TABLE IF NOT EXISTS `past_blocks` ( `height` INTEGER, `difficulty` INTEGER, `hash` TEXT, `timestamp` INTEGER, `reward` INTEGER)",
      "CREATE UNIQUE INDEX IF NOT EXISTS `name_index` ON `worker_hashrate` (`name`, `timestamp`)",
      "CREATE INDEX IF NOT EXISTS `timeindex` ON `worker_hashrate` ( `timestamp`)",
      "BEGIN TRANSACTION"
    ]

    for c <- commands do
      :ok = Exqlite.Sqlite3.execute(conn, c)
    end

    {:ok, insert_pastblock_stmt} =
      Exqlite.Sqlite3.prepare(
        conn,
        "INSERT INTO `past_blocks` (`height`, `difficulty`, `hash`, `timestamp`, `reward`) VALUES (?,?,?,?,?)"
      )

    {:ok, select_pastblock_stmt} =
      Exqlite.Sqlite3.prepare(
        conn,
        # "SELECT `height`, `difficulty`, `hash`, `timestamp`, `reward` FROM `past_blocks` LIMIT ? "
        "SELECT `height`, `difficulty`, `hash`, `timestamp`, `reward` FROM `past_blocks` ORDER BY `rowid` DESC LIMIT ?"
      )

    {:ok, select_dayblocks_stmt} =
      Exqlite.Sqlite3.prepare(
        conn,
        # "SELECT `date`, `blocks` FROM `day_blocks` LIMIT ? ORDER BY `date` DESC"
        "SELECT `date`, `blocks` FROM `day_blocks` ORDER BY `date` DESC LIMIT ?"
      )

    {:ok, insert_dayblock_stmt} =
      Exqlite.Sqlite3.prepare(
        conn,
        "INSERT OR REPLACE INTO `day_blocks` (`date`, `blocks`) VALUES (?,?)"
      )

    {:ok, select_dayblock_stmt} =
      Exqlite.Sqlite3.prepare(
        conn,
        "SELECT `blocks` FROM `day_blocks` WHERE `date`=?"
      )

    {:ok, insert_stmt} =
      Exqlite.Sqlite3.prepare(
        conn,
        "INSERT OR IGNORE INTO `worker_hashrate` (`name`, `hashrate`, `timestamp`) VALUES (?,?,?)"
      )

    {:ok, inserttime_stmt} =
      Exqlite.Sqlite3.prepare(
        conn,
        "INSERT OR IGNORE INTO `hashrate_times` (`timestamp`) VALUES (?)"
      )

    {:ok, latesttime_stmt} =
      Exqlite.Sqlite3.prepare(
        conn,
        "SELECT `timestamp` FROM `hashrate_times` ORDER BY `timestamp` DESC LIMIT 1"
      )

    {:ok, select_stmt} =
      Exqlite.Sqlite3.prepare(
        conn,
        "SELECT `timestamp`, `hashrate` FROM `worker_hashrate` WHERE `name`=? and `timestamp`>= ? and `timestamp` <= ?"
      )

    {:ok, deleteold_stmt} =
      Exqlite.Sqlite3.prepare(
        conn,
        "DELETE FROM `worker_hashrate` WHERE `timestamp`<= ?"
      )

    {:ok,
     %{
       select_dayblocks_stmt: select_dayblocks_stmt,
       insert_dayblock_stmt: insert_dayblock_stmt,
       select_dayblock_stmt: select_dayblock_stmt,
       insert_pastblock_stmt: insert_pastblock_stmt,
       select_pastblock_stmt: select_pastblock_stmt,
       insert_stmt: insert_stmt,
       inserttime_stmt: inserttime_stmt,
       latesttime_stmt: latesttime_stmt,
       select_stmt: select_stmt,
       deleteold_stmt: deleteold_stmt,
       conn: conn
     }}
  end

  @impl true
  def handle_info(:flush, state) do
    :ok = Exqlite.Sqlite3.execute(state.conn, "END TRANSACTION; BEGIN TRANSACTION;")
    Process.send_after(self(), :flush, :timer.seconds(30))
    {:noreply, state}
  end

  @impl true
  def handle_cast(:flush, state) do
    :ok = Exqlite.Sqlite3.execute(state.conn, "END TRANSACTION; BEGIN TRANSACTION;")
    {:noreply, state}
  end

  @impl true
  def handle_cast({:deleteold, timestamp}, state) when is_integer(timestamp) do
    stmt = state.deleteold_stmt
    :ok = Exqlite.Sqlite3.bind(state.conn, stmt, [timestamp])
    :done = Sqlite3.step(state.conn, stmt)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:insert, name, hashrate, timestamp}, state)
      when is_binary(name) and is_number(hashrate) and is_integer(timestamp) do
    stmt = state.insert_stmt
    :ok = Exqlite.Sqlite3.bind(state.conn, stmt, [name, hashrate, timestamp])
    :done = Sqlite3.step(state.conn, stmt)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:insert_hashratetime, timestamp}, state) do
    stmt = state.inserttime_stmt
    :ok = Exqlite.Sqlite3.bind(state.conn, stmt, [timestamp])
    :done = Exqlite.Sqlite3.step(state.conn, stmt)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:insert_pastblock, {h, d, hash, t, r}}, state)
      when is_integer(h) and is_integer(d) and is_binary(hash) and is_integer(t) and is_integer(r) do
    stmt = state.insert_pastblock_stmt
    :ok = Exqlite.Sqlite3.bind(state.conn, stmt, [h, d, hash, t, r])
    :done = Exqlite.Sqlite3.step(state.conn, stmt)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:inc_day_blocks, daystring}, state) when is_binary(daystring) do
    stmt = state.select_dayblock_stmt
    :ok = Exqlite.Sqlite3.bind(state.conn, stmt, [daystring])

    blocks =
      case Exqlite.Sqlite3.fetch_all(state.conn, stmt) do
        {:ok,[]} -> 0
        {:ok,[[blocks]]} -> blocks
      end

    stmt = state.insert_dayblock_stmt
    :ok = Exqlite.Sqlite3.bind(state.conn, stmt, [daystring, blocks + 1])
    :done = Exqlite.Sqlite3.step(state.conn, stmt)
    {:noreply, state}
  end

  @impl true
  def handle_call({:select, name, since, until}, _from, state) do
    stmt = state.select_stmt
    :ok = Exqlite.Sqlite3.bind(state.conn, stmt, [name, since, until])
    res = Exqlite.Sqlite3.fetch_all(state.conn, stmt)
    {:reply, res, state}
  end

  @impl true
  def handle_call({:select_pastblocks, n}, _from, state) when is_integer(n) do
    stmt = state.select_pastblock_stmt
    :ok = Exqlite.Sqlite3.bind(state.conn, stmt, [n])
    res = Exqlite.Sqlite3.fetch_all(state.conn, stmt)
    {:reply, res, state}
  end

  @impl true
  def handle_call({:get_day_blocks, n}, _from, state) do
    stmt = state.select_dayblocks_stmt
    :ok = Exqlite.Sqlite3.bind(state.conn, stmt, [n])
    res = Exqlite.Sqlite3.fetch_all(state.conn, stmt)
    {:reply, res, state}
  end

  @impl true
  def handle_call(:get_latest_hashratetime, _from, state) do
    stmt = state.latesttime_stmt

    case Exqlite.Sqlite3.step(state.conn, stmt) do
      :done ->
        {:reply, nil, state}

      {:row, [time]} ->
        :done = Exqlite.Sqlite3.step(state.conn, stmt)
        {:reply, time, state}
    end
  end

  def flush() do
    GenServer.cast(__MODULE__, :flush)
  end

  def insert_hashrate(name, timestamp, hashrate)
      when is_binary(name) and is_number(hashrate) and is_integer(timestamp) do
    GenServer.cast(__MODULE__, {:insert, name, hashrate, timestamp})
  end

  def deleteold_hashrate(timestamp) when is_integer(timestamp) do
    GenServer.cast(__MODULE__, {:deleteold, timestamp})
  end

  def select_hashrate(name, since, until)
      when is_binary(name) and is_integer(since) and is_integer(until) do
    GenServer.call(__MODULE__, {:select, name, since, until})
  end

  def get_latest_hashratetime() do
    GenServer.call(__MODULE__, :get_latest_hashratetime)
  end

  def insert_hashratetime(timestamp) do
    GenServer.cast(__MODULE__, {:insert_hashratetime, timestamp})
  end

  def select_pastblocks(n) when is_integer(n) do
    GenServer.call(__MODULE__, {:select_pastblocks, n})
  end

  def insert_pastblock(%{
        height: h,
        difficulty: d,
        hash: hash,
        timestamp: t,
        reward: r
      })
      when is_integer(h) and is_integer(d) and is_binary(hash) and
             is_integer(t) and is_integer(r) do
    GenServer.cast(__MODULE__, {:insert_pastblock, {h, d, hash, t, r}})
  end

  def inc_day_blocks(daystring) when is_binary(daystring) do
    GenServer.cast(__MODULE__, {:inc_day_blocks, daystring})
  end
  def inc_day_blocks() do
    daystring = Timex.now |>  Timex.format!("{YYYY}-{0M}-{0D}")
    inc_day_blocks(daystring)
  end

  def get_day_blocks(n) when is_integer(n) do
    GenServer.call(__MODULE__, {:get_day_blocks, n})
  end
end
