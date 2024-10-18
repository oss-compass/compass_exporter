defmodule CompassAdmin.RiakPool do
  use GenServer

  def conn do
    :poolboy.transaction(__MODULE__, fn(worker)-> GenServer.call(worker, :conn) end)
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(opts) do
    [host, port] = opts
    Riak.Connection.start_link(host, port)
  end

  def handle_call(:conn, _from, state) do
    {:reply, state, state}
  end
end
