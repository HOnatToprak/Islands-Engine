defmodule IslandsEngine.Game do
  use GenServer, start: {__MODULE__, :start_link, []}, restart: :transient
  alias IslandsEngine.{Board, Guesses, Rules, Coordinate, Island}
  def start_link(name) when is_binary(name) do
    GenServer.start_link(__MODULE__, name, name: via_tuple(name))
  end

  @timeout 60 * 60 * 1000
  def init(name) do
    send(self(), {:set_state, name})
    {:ok, fresh_state(name)}
  end

  def via_tuple(name) when is_binary(name) do
    {:via, Registry, {Registry.Game, name}}
  end

  def handle_info(:timeout, state_data) do
    {:stop, {:shutdown, :timeout}, state_data}
  end

  def handle_info({:set_state, name}, _state_data) do
    state_data =
    case :ets.lookup(:game_state, name) do
    [] -> fresh_state(name)
    [{_key, state}] -> state
    end
    :ets.insert(:game_state, {name, state_data})
    {:noreply, state_data, @timeout}
  end

  def add_player(game, name) when is_binary(name) do
    GenServer.call(game, {:add_player, name}, @timeout)
  end

  @players [:player1, :player2]
  def position_island(game, player, key, row, col) when player in @players do
    GenServer.call(game, {:position_island, player, key, row, col})
  end

  def handle_call(:demo_call, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:add_player, name}, _from, state) do
    with  {:ok, rules} <- Rules.check(state.rules, :add_player)
    do
      state
      |> update_player2_name(name)
      |> update_rules(rules)
      |> reply_success(:ok)
    else
      :error -> {:reply, :error, state}
    end
  end

  def handle_call({:position_island, player, key, row, col}, _from, state) do
    board = player_board(state, player)
    with  {:ok, rules} <- Rules.check(state.rules, {:position_island, player}),
          {:ok, coordinate} <- Coordinate.new(row, col),
          {:ok, island} <- Island.new(key, coordinate),
          %{} = board <- Board.position_island(board, key, island)
    do
      state
      |> update_board(player, board)
      |> update_rules(rules)
      |> reply_success(:ok)
    else
      :error -> {:reply, :error, state}
      {:error, :invalid_coordinate} -> {:reply, {:error, :invalid_coordinate}, state}
      {:error, :invalid_island_type} -> {:reply, {:error, :invalid_island_type}, state}
      {:error, :overlapping_island} -> {:reply, {:error, :overlapping_island}, state}
    end
  end

  def handle_call({:set_island, player}, _from, state) do
    board = player_board(state, player)
    with {:ok, rules} <- Rules.check(state.rules, {:set_islands, player}),
         true <- Board.all_islands_positioned?(board)
    do
      state
      |> update_rules(rules)
      |> reply_success(:ok)
    else
      :error -> {:reply, :error, state}
      false -> {:reply, :not_all_islands_positioned, state}
    end
  end

  def handle_call({:guess, player, col, row}, _from, state) do
    opponent_player = opponent(player)
    opponent_board = player_board(state, opponent_player)
    with {:ok, rules} <- Rules.check(state.rules, {:guess_coordinate, player}),
         {:ok, coordinate} <- Coordinate.new(col, row),
         {hit_or_miss, forested_island, win_or_not, _board} <- Board.guess(opponent_board, coordinate),
         {:ok, rules} <- Rules.check(rules, {:win_check, win_or_not})
    do
      state
      |> update_rules(rules)
      |> update_board(opponent(player), opponent_board)
      |> update_guesses(player, hit_or_miss, coordinate)
      |> reply_success({:hit_or_miss, forested_island, win_or_not})
    else
      :error -> {:reply, :error, state}
      {:error, :invalid_coordinate} -> {:reply, {:error, :invalid_coordinate}, state}
    end
  end

  defp update_player2_name(state, name) do
    put_in(state.player2.name, name)
  end

  defp update_rules(state, rules) do
    %{state | rules: rules}
  end

  defp reply_success(state, reply) do
    :ets.insert(:game_state, {state.player1.name, state})
    {:reply, reply, state, @timeout}
  end

  defp fresh_state(name) do
    player1 = %{name: name, board: Board.new(), guesses: Guesses.new()}
    player2 = %{name: nil, board: Board.new(), guesses: Guesses.new()}
    {%{player1: player1, player2: player2, rules: %Rules{}}}
  end

  defp player_board(state, player) do
    Map.get(state, player).board
  end

  defp update_board(state, player, board) do
    Map.update!(state, player, fn player -> %{player | board: board} end)
  end

  defp opponent(:player1), do: :player2
  defp opponent(:player2), do: :player1

  defp update_guesses(state, player_key, hit_or_miss, coordinate) do
    update_in(state[player_key].guesses, fn guesses ->
    Guesses.add(guesses, hit_or_miss, coordinate)
    end)
  end

end
