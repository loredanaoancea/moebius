defmodule Moebius.Query do

  import Inflex, only: [singularize: 1]
  alias Moebius.QueryCommand
  use Moebius.QueryFilter

  @moduledoc """
  The main query interface for Moebius. Import this module into your code and query like a champ
  """

  @doc """
  Specifies the table or view you want to query and returns a QueryCommand struct.

  "table"  -   the name of the table you want to query, such as `membership.users`
  :table  -   the name of the table you want to query, such as `:users`

  Example

  ```
  result = db(:users)
    |> to_list

  result = db("membership.users")
    |> to_list
  ```
  """
  def db(table) when is_atom(table),
    do: db(Atom.to_string(table))

  def db(table),
    do: %QueryCommand{table_name: table}


  @doc """
  Specifies the table or view you want to query and is an alias for the `db/1` function using
  a string or atom as a table name. This is useful for specifying a table within a schema.

  "table"  -   the name of the table you want to query, such as `membership.users`
  :table  -   the name of the table you want to query, such as `:users`

  Example

  ```
  result = with("membership.users")
    |> to_list

  result = with(:users)
    |> to_list
  ```
  """
  def with(table) when is_atom(table),
    do: db(table)

  def with(table),
    do: db(table)



  @doc """
  Searches for a record based on an `id` primary key.

  id      -   The primary key value

  Example:

  ```
  result = db(:users)
      |> find(1)
  ```
  """
  def find(%QueryCommand{} = cmd, id) do
    cmd
      |> filter(id: id)
      |> select_command
      |> first
  end

  @doc """
  Sets the order by. Ascending using `:asc` is the default, you can send in `:desc` if you like.

  cols      -   The atomized name of the columns, such as `:company`
  direction -   `:asc` (default) or `:desc`

  Example:

  ```
  result = db(:users)
      |> sort(:name, :desc)
      |> to_list
  ```
  """
  #def sort(%QueryCommand{} = cmd, cols, direction \\ :asc)

  def sort(%QueryCommand{} = cmd, cols, direction) when is_atom(cols),
    do: sort(cmd, Atom.to_string(cols), direction)

  def sort(%QueryCommand{} = cmd, cols, direction) when is_binary(cols),
    do: %{cmd | order: " order by #{cols} #{direction}"}

  @doc """
  Sets the limit of the return.

  bound   -   And integer limiter

  Example:

  ```
  result = db(:users)
      |> limit(20)
      |> to_list
  ```
  """
  def limit(cmd, bound) when is_integer(bound),
    do: %{cmd | limit: " limit #{bound}"}

  @doc """
  Offsets the limit and is an alias for `skip/1`"

  Example:

  ```
  result = db(:users)
      |> limit(20)
      |> offset(2)
      |> to_list
  ```
  """
  def offset(cmd, n),
    do: %{cmd | offset: " offset #{n}"}

  @doc """
  Offsets the limit and is an alias for `offset/1`"

  Example:

  ```
  result = db(:users)
      |> limit(20)
      |> skip(2)
      |> to_list
  ```
  """
  def skip(%QueryCommand{} = cmd, n),
    do: offset(cmd, n)

  @doc """
  Creates a SELECT command based on the assembled pipeline. Uses the QueryCommand as its core structure.

  cols  -   Any columns (specified as a string) that you want to have aliased or restricted in your return.
            For example `now() as current_time, name, description`

  Example:

  ```
  command = db(:users)
      |> limit(20)
      |> offset(2)
      |> select_command("now() as current_time, name, description")

  #command is a QueryCommand object with all of the pipelined settings applied
  ```
  """
  def select_command(%QueryCommand{} = cmd, cols \\ "*") when is_bitstring(cols) do
    %{cmd | sql: "select #{cols} from #{cmd.table_name}#{cmd.join}#{cmd.where}#{cmd.order}#{cmd.limit}#{cmd.offset};"}
  end

  @doc """
  Executes a COUNT query based on the assembled pipeline. Analagous to `map/reduce(:count)`. Returns an integer.

  Example:

  count = db(:users)
      |> limit(20)
      |> count

  #count == 20
  """
  def count(%QueryCommand{} = cmd) do
    res = %{cmd | sql: "select count(1) from #{cmd.table_name}#{cmd.join}#{cmd.where}#{cmd.order}#{cmd.limit}#{cmd.offset};"}
      |> execute(:single)

    case res do
      {:error, err} -> {:error, err}
      row -> row.count
    end
  end

  @doc """
  Executes a given pipeline and returns the first matching result. You should specify a `sort` to be sure first works as intended.

  cols  -   Any columns (specified as a string) that you want to have aliased or restricted in your return.
            For example `now() as current_time, name, description`. Defaults to "*"


  Example:

  ```
  top_spender = db(:users)
    |> sort(:money_spent, :desc)
    |> first("first, last, email")
  ```
  """
  def first(%QueryCommand{} = cmd, cols \\ "*") do
    res = cmd
          |> select_command(cols)
          |> execute(:single)

    cond do
      res == [] -> nil
      true -> res
    end
  end

  @doc """
  Executes a given pipeline and returns the last matching result. You should specify a `sort` to be sure first works as intended.

  cols  -   Any columns (specified as a string) that you want to have aliased or restricted in your return.
            For example `now() as current_time, name, description`. Defaults to "*"


  Example:

  ```
  cheap_skate = db(:users)
    |> sort(:money_spent, :desc)
    |> last("first, last, email")
  ```
  """
  def last(%QueryCommand{} = cmd, sort_by) when is_atom(sort_by) do
    cmd
    |> sort(sort_by, :desc)
    |> select_command
    |> execute(:single)
  end

  @doc """
  Executes a given pipeline and returns all results. An alias for `all/2`

  cols  -   Any columns (specified as a string) that you want to have aliased or restricted in your return.
            For example `now() as current_time, name, description`. Defaults to "*"


  Example:

  ```
  all_users = db(:users)
    |> to_list("first, last, email")
  ```
  """
  def to_list(%QueryCommand{} = cmd, cols \\ "*"),
    do: all(cmd, cols)

  @doc """
  Executes a given pipeline and returns all results. An alias for `to_list/2`

  cols  -   Any columns (specified as a string) that you want to have aliased or restricted in your return.
            For example `now() as current_time, name, description`. Defaults to "*"


  Example:

  ```
  all_users = db(:users)
    |> all("first, last, email")
  ```
  """
  def all(%QueryCommand{} = cmd, cols \\ "*") do
    cmd
    |> select_command(cols)
    |> execute
  end

  @doc """
  Specifies a GROUP BY for a `map/reduce` (aggregate) query.

  cols  -   An atom indicating the column to GROUP BY. Will also be part of the SELECT list.


  Example:

  ```
  result = db(:users)
    |> map("money_spent > 100")
    |> group(:company)
    |> reduce(:sum, :money_spent)
  ```
  """
  def group(%QueryCommand{} = cmd, cols) when is_atom(cols),
    do: group(cmd, Atom.to_string(cols))

  @doc """
  Specifies a GROUP BY for a `map/reduce` (aggregate) query that is a string.

  cols  -   A string specifying the column to GROUP BY. Will also be part of the SELECT list.

  Example:

  ```
  result = db(:users)
    |> map("money_spent > 100")
    |> group("company, state")
    |> reduce(:sum, :money_spent)
  ```
  """
  def group(%QueryCommand{} = cmd, cols),
    do: %{cmd | group_by: cols}

  @doc """
  An alias for `filter`, specifies a range to rollup on for an aggregate query using a WHERE statement.

  criteria  -   A string, atom or list (see `filter`)

  Example:

  ```
  result = db(:users)
    |> map("money_spent > 100")
    |> reduce(:sum, :money_spent)
  ```
  """
  def map(%QueryCommand{} = cmd, criteria),
    do: filter(cmd, criteria)

  @doc """
  A rollup operation that aggregates the mapped result set by the specified operation.

  op  -   An atom indicating what you want to have happen, such as `:sum`, `:avg`, `:min`, `:max`.
          Corresponds directly to a PostgreSQL rollup function.

  Example:

  ```
  result = db(:users)
    |> map("money_spent > 100")
    |> reduce(:sum, :money_spent)
  ```
  """
  def reduce(%QueryCommand{} = cmd, op, column) when is_atom(column),
    do: reduce(cmd, op, Atom.to_string(column))

  def reduce(%QueryCommand{} = cmd, op, column) when is_bitstring(column) do
    sql = cond do
      cmd.group_by ->
        "select #{op}(#{column}), #{cmd.group_by} from #{cmd.table_name}#{cmd.join}#{cmd.where} GROUP BY #{cmd.group_by}"
      true ->
        "select #{op}(#{column}) from #{cmd.table_name}#{cmd.join}#{cmd.where}"
    end

    res = %{cmd | sql: sql}
      |> execute(:single)

    case res do
      {:error, err} -> {:error, err}
      nil -> 0
      row -> Map.get(row, op)
    end
  end

  @doc """
  Full text search using Postgres' built in indexing, ranked using `tsrank`. This query will result in a full table scan and is not optimized for large result
  sets. For better results, create a `tsvector` field and populate it with a trigger on insert/update. This will cause some side
  effects, one of them being that Postgrex, the Elixir driver we use, doesn't know how to resolve the tsvector type, and will throw.

  You will need to be sure that you exclude that search column from your query.

  for:  -   The string term you want to query against.
  in:   -   An atomized list of columns to search againts.

  Example:

  ```
  result = db(:users)
        |> search(for: "Mike", in: [:first, :last, :email])
        |> run
  ```
  """
  def search(%QueryCommand{} = cmd, for: term, in: columns) when is_list columns do
    concat_list = Enum.map_join(columns, ", ' ',  ", &"#{&1}")
    sql = """
    select *, ts_rank_cd(to_tsvector(concat(#{concat_list})),to_tsquery($1)) as rank from #{cmd.table_name}
  	where to_tsvector(concat(#{concat_list})) @@ to_tsquery($1)
  	order by rank desc
    """

    %{cmd | sql: sql, params: [term]}
  end


  @doc """
  Insert multiple rows at once, within a single transaction, returning the inserted records. Pass in a composite list, containing the rows  to be inserted.
  Note, the columns to be inserted are defined based on the first record in the list. All records to be inserted must adhere to the same schema.

  Example:

  ```
  data = [
    [first_name: "John", last_name: "Lennon", address: "123 Main St.", city: "Portland", state: "OR", zip: "98204"],
    [first_name: "Paul", last_name: "McCartney", address: "456 Main St.", city: "Portland", state: "OR", zip: "98204"],
    [first_name: "George", last_name: "Harrison", address: "789 Main St.", city: "Portland", state: "OR", zip: "98204"],
    [first_name: "Paul", last_name: "Starkey", address: "012 Main St.", city: "Portland", state: "OR", zip: "98204"],

  ]
  result = db(:people) |> insert(data)
  ```
  """
  def insert(%QueryCommand{} = cmd, [[hd | _] | _] = records) when is_tuple(hd) do

    # need a single definitive column map to arrest and roll back Tx if
    # and of the inputs are malformed (different cols vs. vals)
    column_map = records |> hd |> Keyword.keys

    transaction fn(pid) ->
      cmd
      |> bulk_insert_batch(records, [], column_map)
      |> Enum.map(fn(cmd) -> execute(cmd, pid) end)
      |> List.flatten
    end

  end

  defp bulk_insert_batch(%QueryCommand{} = cmd, records, acc, column_map) do

    # 20,000 seems to be the optimal number here. Technically you can go up to 34,464, but I think Postgrex imposes a lower limit, as I
    # hit a wall at 34,000, but succeeded at 30,000. Perf on 100k records is best at 20,000.
    max_params = 20000
    cmd = %{ cmd | columns: column_map}
    max_records_per_command = div(max_params, length(cmd.columns))

    { current, next_batch } = Enum.split(records, max_records_per_command)
    this_cmd = bulk_insert_command(cmd, current)
    case next_batch do
      [] -> Enum.reverse([this_cmd | acc])
      _ ->
        db(cmd.table_name) |> bulk_insert_batch(next_batch, [this_cmd | acc], column_map)
    end
  end

  defp bulk_insert_command(%QueryCommand{} = cmd, [first | rest]) do
    records = [first | rest]
    cols = cmd.columns
    vals = Enum.reduce(Enum.reverse(records), [], fn(listitem, acc) ->
      Enum.concat(Keyword.values(listitem), acc) end)

    params_sql = elem(Enum.map_reduce(vals, 0, fn(v, acc) -> {"$#{acc + 1}", acc + 1} end),0)
    |> Enum.chunk(length(cols), length(cols), [])
    |> Enum.map(fn(chunk) -> "(#{Enum.join(chunk, ", ")})" end)
    |> Enum.join(", ")

    sql_body = "insert into #{cmd.table_name} (" <> Enum.join(cols, ", ") <> ") " <>
    "values #{ params_sql } returning *;"

    %{cmd | columns: cols, sql: sql_body, params: vals, type: :insert}
  end

  @doc """
  A simple insert that is part of a transaction that returns the inserted record. Create your list of data and send it on in.

  pid:        -    The process id of the transaction (retrieved from the `transaction` callback)
  criteria:   -    A list or map of data to be saved

  Example:

  ```
  tranaction fn(pid) ->
    new_user = db(:users)
        |> insert(pid, email: "test@test.com", first: "Test", last: "User")
  end
  ```
  """
  def insert(%QueryCommand{} = cmd, pid, criteria) when is_pid(pid) do
    cmd
    |> insert_command(criteria)
    |> execute(:single, pid)
  end

  @doc """
  A simple insert that that returns the inserted record. Create your list of data and send it on in.

  criteria:   -    A list or map of data to be saved

  Example:

  ```
  new_user = db(:users)
      |> insert(email: "test@test.com", first: "Test", last: "User")
  ```
  """
  def insert(%QueryCommand{} = cmd, criteria) do
    cmd
    |> insert_command(criteria)
    |> execute(:single)
  end

  @doc """
  Creates an insert command based on the assembled pipeline
  """
  def insert_command(%QueryCommand{} = cmd, criteria) do
    cols = Keyword.keys(criteria)
    vals = Keyword.values(criteria)
    sql = "insert into #{cmd.table_name}(" <> Enum.map_join(cols, ", ", &"#{&1}") <> ")" <>
    " values(" <> Enum.map_join(1..length(cols), ", ", &"$#{&1}") <> ") returning *;"

    %{cmd | sql: sql, params: vals, type: :insert}
  end

  @doc """
  Creates an update command based on the assembled pipeline.
  """
  def update_command(%QueryCommand{} = cmd, criteria) do

    cols = Keyword.keys(criteria)
    vals = Keyword.values(criteria)

    {cols, col_count} = Enum.map_reduce cols, 1, fn col, acc ->
      {"#{col} = $#{acc}", acc + 1}
    end

    #here's something for John to clean up :):)
    where = cond do

      length(cmd.where_columns) > 0 ->
        {filters, _count} = Enum.map_reduce cmd.where_columns, col_count, fn col, acc ->
          {"#{col} = $#{acc}", acc + 1}
        end
        " where " <> Enum.join(filters, " and ")

      cmd.where -> cmd.where
    end

    params = cond do
      length(cmd.params) > 0 && length(vals) > 0 ->
        List.flatten(vals,cmd.params)
      length(vals) > 0 -> vals
    end

    sql = "update #{cmd.table_name} set " <> Enum.join(cols, ", ") <> where <> " returning *;"
    %{cmd | sql: sql, type: :update, params: params}
  end


  @doc """
  A simple update that is part of a transaction based on the criteria you specify. This is a partial update.
  Returns a single record as a result when you pass `:single`

  pid:        -    The process id of the transaction (retrieved from the `transaction` callback)
  criteria:   -    A list or map of data to be saved

  Example:

  ```
  tranaction fn(pid) ->
    updated_user = db(:users)
        |> update(pid, :single, email: "test@test.com", first: "Test", last: "User")
  end
  ```
  """
  def update(%QueryCommand{} = cmd, pid, :single, criteria) when  is_pid(pid) and is_list(criteria) do
    cmd
    |> update_command(criteria)
    |> execute(:single, pid)
  end

  @doc """
  A simple update based on the criteria you specify. This is a partial update.
  Returns a single record as a result when you pass `:single`

  pid:        -    The process id of the transaction (retrieved from the `transaction` callback)
  criteria:   -    A list or map of data to be saved

  Example:

  ```

  updated_user = db(:users)
      |> update(:single, email: "test@test.com", first: "Test", last: "User")

  ```
  """
  def update(%QueryCommand{} = cmd, :single, criteria) when is_list(criteria) do
    cmd
    |> update_command(criteria)
    |> execute(:single)
  end

  @doc """
  A bulk update based on the criteria you specify. All changed records are returned.

  Example:

  ```
  db(:users)
    |> filter(company: "Test Company")
    |> update(status: "preferred")
  ```
  """
  def update(%QueryCommand{} = cmd, criteria) when is_list(criteria) do
    cmd
    |> update_command(criteria)
    |> execute
  end

  @doc """
  Creates a DELETE command
  """
  def delete_command(%QueryCommand{} = cmd) do
    sql = "delete from #{cmd.table_name}" <> cmd.where <> ";"
    %{cmd | sql: sql, type: :delete}
  end

  @doc """
  Deletes a record based on your filter, part of a transaction.

  pid:  -   The process id from the current transaction callback.

  Example:

  ```
  transaction fn(pid) ->
    db(:users)
      |> filter("id > $1", 1)
      |> delete(pid)
  end
  ```
  """
  def delete(%QueryCommand{} = cmd, pid) when is_pid(pid) do
    cmd
    |> delete_command
    |> execute(:single, pid)
  end

  @doc """
  Deletes a record based on your filter.
  Example:

  ```

  db(:users)
    |> filter("id > $1", 1)
    |> delete

  ```
  """
  def delete(%QueryCommand{} = cmd) do
    cmd
    |> delete_command
    |> execute(:single)
  end

  @doc """
  Build a table join for your query. There are a number of options to handle various joins.
  Joins can also be piped for multiple joins.

  :join        - set the type of join. LEFT, RIGHT, FULL, etc. defaults to INNER
  :on          - specify the table to join on
  :foreign_key - specify the tables foreign key column
  :primary_key - specify the joining tables primary key column
  :using       - used to specify a USING queries list of columns to join on

  Example of simple join:
  ```
    cmd = db(:customers)
        |> join(:orders)
        |> select
  ```

  Example of multiple table joins:
  ```
    cmd = db(:customers)
        |> join(:orders, on: :customers)
        |> join(:items, on: :orders)
        |> select
  ```
  """
  def join(%QueryCommand{} = cmd, table, opts \\ []) do
    join_type   = Keyword.get(opts, :join, "inner")
    join_table  = Keyword.get(opts, :on, cmd.table_name)
    foreign_key = Keyword.get(opts, :foreign_key, "#{singularize(join_table)}_id")
    primary_key = Keyword.get(opts, :primary_key, "id")
    using       = Keyword.get(opts, :using, nil)

    join_condition = case using do
      nil ->
        " #{join_type} join #{table} on #{join_table}.#{primary_key} = #{table}.#{foreign_key}"
      cols ->
        " #{join_type} join #{table} using (#{Enum.join(cols, ", ")})"
    end

    %{cmd | join: [cmd.join|join_condition]}
  end

  @doc """
  Executes the SQL in a given SQL file without parameters. Specify the scripts directory by setting the `scripts` directive in the config.
  Pass the file name as an atom, without extension.

  ```
  result = sql_file(:simple)
  """
  def sql_file(file) do
    file
    |> sql_file_command([])
    |> execute
  end

  @doc """
  Executes the SQL in a given SQL file with the specified parameters, returning a single result.
  Specify the scripts directory by setting the `scripts` directive in the config.
  Pass the file name as an atom, without extension.

  ```
  result = sql_file(:save_user, [1])
  ```
  """
  def sql_file(file, :single, params) do
    file
    |> sql_file_command(params)
    |> execute(:single)
  end

  @doc """
  Executes the SQL in a given SQL file with the specified parameters. Specify the scripts
  directory by setting the `scripts` directive in the config. Pass the file name as an atom,
  without extension.

  ```
  result = sql_file(:save_user, [1])
  ```
  """
  def sql_file(file, params) do
    file
    |> sql_file_command(params)
    |> execute
  end

  @doc """
  Creates a SQL File command
  """
  def sql_file_command(file, params \\ [])

  def sql_file_command(file, params) when not is_list(params),
    do: sql_file_command(file, [params])

  def sql_file_command(file, params) do
    #find the DB dir
    scripts_dir = Application.get_env(:moebius, :scripts)
    file_path = Path.join(scripts_dir, "#{Atom.to_string(file)}.sql")
    sql=File.read!(file_path)

    %Moebius.QueryCommand{sql: String.strip(sql), params: params}
  end

  @doc """
  Executes a function with the given name, passed as an atom.

  Example:

  ```
  result = db(:users)
    |> function(:all_users)

  ```
  """
  def function(function_name) do
    function_name
    |> function_command([])
    |> execute
  end

  @doc """
  Executes a function with the given name, passed as an atom, returning a single result.

  params:   -   An array of values to be passed to the function.

  Example:

  ```
  result = db(:users)
    |> function(:friends, ["mike","jane"])

  ```
  """
  def function(function_name, :single) do
    function_name
    |> function_command([])
    |> execute(:single)
  end

  @doc """
  Executes a function with the given name, passed as an atom.

  params:   -   An array of values to be passed to the function.

  Example:

  ```
  result = db(:users)
    |> function(:friends, ["mike","jane"])

  ```
  """
  def function(function_name, params) do
    function_name
    |> function_command(params)
    |> execute
  end

  @doc """
  Executes a function with the given name, passed as an atom, returning a single result.

  Example:

  ```
  result = db(:users)
    |> function(:all_users)

  ```
  """
  def function(function_name, :single, params) do
    function_name
    |> function_command(params)
    |> execute(:single)
  end

  @doc """
  Creates a function command
  """
  def function_command(function_name, params \\ [])

  def function_command(function_name, params) when not is_list(params),
    do: function_command(function_name, [params])

  def function_command(function_name, params) do
    arg_list = cond do
      length(params) > 0 ->  Enum.map_join(1..length(params), ", ", &"$#{&1}")
      true -> ""
    end

    sql = "select * from #{function_name}(#{arg_list});"
    %Moebius.QueryCommand{sql: sql, params: params}
  end


  @doc """
  Executes a raw SQL query without parameters
  """
  def run(sql) when is_bitstring(sql),
    do: run(sql, [])

  def run(sql, :single) when is_bitstring(sql),
    do: run(sql, [], :single)

  def run(sql, params) when is_bitstring(sql) do
    %Moebius.QueryCommand{sql: sql, params: params}
    |> execute
  end

  @doc """
  Executes a raw SQL query with parameters returning a single result
  """
  def run(sql, params, :single) when is_bitstring(sql) do
    %Moebius.QueryCommand{sql: sql, params: params}
    |> execute(:single)
  end

  @doc """
  Executes a pass-through query and returns a single result as part of a transaction
  """
  def execute(%QueryCommand{} = cmd, :single, pid) when is_pid(pid) do
    cmd
    |> Moebius.Runner.execute(pid)
    |> Moebius.Transformer.to_single
  end

  @doc """
  Executes a command, returning a list of results
  """
  def execute(%QueryCommand{} = cmd) do
    cmd
    |> Moebius.Runner.execute
    |> Moebius.Transformer.to_list
  end

  @doc """
  Executes a pass-through query and returns a single result
  """
  def execute(%QueryCommand{} = cmd, :single) do
    cmd
    |> Moebius.Runner.execute
    |> Moebius.Transformer.to_single
  end

  @doc """
  Executes a command, returning a list of results as part of a transaction
  """
  def execute(%QueryCommand{} = cmd, pid) when is_pid(pid) do
    cmd
    |> Moebius.Runner.execute(pid)
    |> Moebius.Transformer.to_list
  end

  @doc """
  Opens a transaction, returning a `pid` (Process ID) that you can pass to each of your queries that take part in the transaction.
  If an error occurs, it is passed back to you with `{:error, message}`. The transaction will automatically COMMIT on completion.

  Example:

  ```
  result = transaction fn(pid) ->
    new_user = with(:users)
      |> insert(pid, email: "frodo@test.com")

    with(:logs)
      |> insert(pid, user_id: new_user.id, log: "Hi Frodo")

    new_user
  end
  ```
  """

  def transaction(fun) do
    pid = Moebius.Runner.open_transaction()
    res = try do
      fun.(pid)
    rescue
      e in RuntimeError -> {:error, e.message}
    end
    Moebius.Runner.commit_and_close_transaction(pid)
    res
  end

end
