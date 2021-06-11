defmodule Playboard do 

  @name __MODULE__

  def start_link(),
  do: Agent.start_link(fn -> [[], [], [], [], [], [], []] end, name: @name)
  
  def addTileAt(tile, pos) do
    Agent.update(@name, &updateBoard(&1, tile, pos))
    getBoard()
  end

  def getBoard(),
  do: Agent.get(@name, &(&1))

  defp updateBoard(board, tile, pos),
  do: List.update_at(board, pos, fn x -> x ++ [tile] end)

  def stop(), do: Agent.stop(@name)

end

defmodule ConnectFour do

  def checkWinCondition(board) do
    fillBoard(board)
    |> getAllConnections
    |> Enum.any?(fn x -> fourConnected x end)
  end

  defp fourConnected(list) do
    str = to_string(list)
    str =~ "OOOO" || str =~ "XXXX" 
  end

  defp getAllConnections(board), 
  do: board ++ transpose(board) ++ allDiagonals(board)
  
  defp transpose(board), 
  do: Enum.zip(board) |> Enum.map(&(Tuple.to_list &1))

  defp allDiagonals(board) do
    diagonals(board) ++ diagonals(Enum.reverse(board))
    |> Enum.map(fn x -> Enum.filter(x, fn y -> !is_nil y end) end)
    |> Enum.filter(fn l -> length(l) >= 4 end)
  end

  defp diagonals(board) do
    {h, w} = {length(board), board |> List.first |> length}
    for p <- 0..(h + w - 1), do: 
      for q <- max(p - h + 1, 0)..min(p + 1, w), do:
        board |> Enum.at(h - q - 1) |> Enum.at(p - q) 
  end

  def printBoard(board) do
    fillBoard(board)
    |> transpose |> Enum.reverse |> Enum.map(&(IO.puts &1))
  end

  def fillBoard(board), do: Enum.map(board, &(fillList &1))

  defp fillList(list) when length(list) < 6, 
  do: list ++ for _ <- 1..(6-length(list)), do: '.'

end

defmodule Player do

  def startPlayer1() do
    Node.start(:"player1@127.0.0.1")
    Playboard.start_link
    Playboard.getBoard |> ConnectFour.printBoard
    player1 = spawn(Player, :loop, [])
    :global.register_name(:server, player1)
  end

  def startPlayer2() do
    Node.start(:"player2@127.0.0.1")
    Node.connect(:"player1@127.0.0.1")
    Playboard.start_link
    Playboard.getBoard |> ConnectFour.printBoard
    turn = getNextTurn('X')
    addTileAndPrintBoard(turn)
    player2 = spawn(Player, :loop, [])
    :global.whereis_name(:server) 
    |> send {player2, turn}
  end

  def loop() do
    receive do
      {sender, {tile, column}} ->
        turn = processTurn(tile, column)
        case turn do
          true -> 
            IO.puts("You won")
            Playboard.stop()
            send sender, {"over"}
          _ ->        
            send sender,{self(), turn}
            loop()
        end
      {"over"} -> 
        IO.puts("You lost! Game over")
        Playboard.stop()
    end
  end

  defp processTurn(tile, column) do 
    addTileAndPrintBoard(tile, column)
    turn = getTile(tile) |> getNextTurn()
    addTileAndPrintBoard(turn)
    case Playboard.getBoard |> ConnectFour.checkWinCondition do
      false -> turn
      _ -> true 
    end
  end

  defp getNextTurn(tile) do
    {turn, _} = IO.gets("enter column \n") |> Integer.parse
    {tile, turn}
  end

  defp addTileAndPrintBoard({tile, column}), 
  do: addTileAndPrintBoard(tile, column)

  defp addTileAndPrintBoard(tile, column),
  do: Playboard.addTileAt(tile, column) |> ConnectFour.printBoard

  defp getTile(tile) do
    case tile do
      'X' -> 'O'
      'O' -> 'X'
    end
  end

end