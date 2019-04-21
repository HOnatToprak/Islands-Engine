defmodule IslandsEngine.Game do
  use GenServer
  alias IslandsEngine.{Board, Guesses, Rules, Coordinate, Island, Game}

  def add_player(game, name) when is_binary(name) do
    GenServer.call(game, {:add_player, name})
  end

  @players [:player1, :player2]
  def position_island(game, player, key, row, col) when player in @players do
    GenServer.call(game, {:position_island, player, key, row, col})
  end

  def start_link(name) when is_binary(name) do
    GenServer.start_link(__MODULE__, name, name: via_tuple(name))
  end

  def init(name) do
    player1 = %{name: name, board: Board.new(), guesses: Guesses.new()}
    player2 = %{name: nil, board: Board.new(), guesses: Guesses.new()}
    {:ok, %{player1: player1, player2: player2, rules: %Rules{}}}
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
    end
  end

  def handle_call({:set_island, player}, _from, state) do
    board = player_board(state, player)
    with {:ok, rules} <- Rules.check(state.rules, {:set_islands, player})
         true <- Board.all_islands_positioned?(board)
    do
      state
      |> update_rules(rules)
      |> reply_success(:ok)
    else
      :error -> {:reply, :error, state}
    end
  end

  def handle_call({:guess, player, col, row}, _from, state) do
    board = player_board(state, player)
    opponent_board = player_board(state, opponent(player))
    with {:ok, rules} <- Rules.check(rules, {:guess_coordinate, player})
         {:ok, coordinate} <- Coordinate.new(col, row)
         {hit_or_miss, forested_island, win_or_not, board} <- Board.guess(board, coordinate)
         {:ok, rules}, Rules.check(rules, {:win_check, win_status})
    do
      state
      |> update_rules(rules)
      |> update_board(player, board)
      |> update_guesses(player_key, hit_or_miss, coordinate)
      |> reply_success{:hit_or_miss, forested_island, win_status}
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
    {:reply, reply, state}
  end

  defp player_board(state, player) do
    Map.get(state, player).board
  end

  defp update_board(state_data, player, board) do
    Map.update!(state_data, player, fn player -> %{player | board: board} end)
  end

  defp opponent(:player1), do: :player2
  defp opponent(:player2), do: :player1

  defp update_guesses(state_data, player_key, hit_or_miss, coordinate) do
    update_in(state_data[player_key].guesses, fn guesses ->
    Guesses.add(guesses, hit_or_miss, coordinate)
    end)
  end

  def via_tuple(name) when is_binary(name) do
    {:via, Registry, {Registry.Game, name}}
  end

end
