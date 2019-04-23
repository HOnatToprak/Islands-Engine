defmodule IslandsEngine.Board do
  alias IslandsEngine.{Coordinate, Island}

  def new(), do: %{}

  def position_island(board, key, %Island{} = island) do
    case overlaps_existing_islands?(board, key, island) do
      false -> Map.put(board, key, island)
      true -> {:error, :overlapping_island}
    end
  end

  defp overlaps_existing_islands?(board, new_key, new_island) do
    Enum.any?(board, fn {key, island} ->
      key != new_key and Island.overlaps?(island, new_island)
    end)
  end

  def all_islands_positioned?(board) do
    Enum.all?(Island.types(), &Map.has_key?(board, &1))
  end

  def guess(board, %Coordinate{} = coordinate) do
    board
    |> check_all_islands(coordinate)
    |> guess_response(board)
  end

  # island fnde ve case de isim karmaşası yaratıyor olabilir
  defp check_all_islands(board, coordinate) do
    Enum.find_value(board, :miss, fn {key, island} ->
      case Island.guess(island, coordinate) do
        {:hit, island} -> {key, Island.update_if_forested(island)}
        :miss -> false
      end
    end)
  end

  defp guess_response({key, %{is_forested: is_forested}}, board) do
    island = Map.fetch(board, key)
    board = %{board | key => island}
    case is_forested do
      true -> {:hit, key, win_check(board), board}
      false -> {:hit, :none, :no_win, board}
    end
  end

  defp guess_response(:miss, board), do: {:miss, :none, :no_win, board}

  defp win_check(board) do
    case Enum.all?(board, fn {_, island} ->
           island.is_forested == true
         end) do
      true -> :win
      false -> :no_win
    end
  end
end
