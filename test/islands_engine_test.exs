defmodule IslandsEngineTest do
  use ExUnit.Case
  doctest IslandsEngine
  alias IslandsEngine.{Board, Coordinate, Game, Guesses, Island, Rules, GameSupervisor}

  test "Coordinate Test" do
    assert({:ok, %IslandsEngine.Coordinate{col: 1, row: 1}} = Coordinate.new(1, 1))
    assert({:error, :invalid_coordinate} = Coordinate.new(-1, 1))
    assert({:error, :invalid_coordinate} = Coordinate.new(11, 1))
  end

  test "Guesses Test" do
    {:ok, coordinate1} = Coordinate.new(8, 3)
    guesses = Guesses.new()
    assert(%Guesses{hits: %MapSet{}, misses: %MapSet{}} = guesses)
    guesses = Guesses.add(guesses, :hit, coordinate1)
    assert(MapSet.member?(guesses.hits, coordinate1))
    {:ok, coordinate2} = Coordinate.new(1, 2)
    guesses = Guesses.add(guesses, :miss, coordinate2)
    assert(MapSet.member?(guesses.misses, coordinate2))
    guesses = Guesses.add(guesses, :miss, coordinate2)
    assert(1 = MapSet.size(guesses.misses))
  end

  test "Island Test" do
    {:ok, dot_coordinate} = Coordinate.new(4, 4)
    assert({:ok, dot} = Island.new(:dot, dot_coordinate))
    {:ok, coordinate} = Coordinate.new(2, 2)
    assert(:miss = Island.guess(dot, coordinate))
    {:ok, new_coordinate} = Coordinate.new(4, 4)
    {:hit, dot} = Island.guess(dot, new_coordinate)
    assert(Island.forested?(dot))
  end

  test "Add Player" do
    {:ok, game} = GameSupervisor.start_game("Morandi")
    Game.add_player(game, "Rothko")
  end
end
