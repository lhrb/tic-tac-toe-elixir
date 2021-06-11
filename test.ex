defmodule Server do
  def square() do
    receive do
      {from, tag, x} ->
        send from, {self(), tag, x*x}
    end
    square()
  end
end


pid = spawn(Server, :square, [])
tag = :erlang.make_ref()
send pid, {self(), tag, 10}

receive do
  {pid, tag, reply} ->
    IO.puts(reply)
end