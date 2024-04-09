defmodule Mix.Tasks.Deploy do
  use Mix.Task

  @shortdoc "Simple deploy script for compass_admin on multiple machines"
  def run(_) do
    hosts =
      Application.get_env(:compass_admin, :hostnames)
      |> Keyword.values()
      |> Enum.uniq()

    Enum.each(hosts, fn host ->
      IO.puts(IO.ANSI.format([:green, "begin syncing #{host}"]))

      result =
        "rsync -arvz --progress --delete _build/prod/rel/compass_admin git@#{host}:~/"
        |> IO.inspect(label: "current execute")
        |> String.to_charlist()
        |> :os.cmd()

      IO.puts(IO.ANSI.format([:green, "#{host} synced"]))
      IO.puts(result)
    end)

    Enum.each(hosts, fn host ->
      IO.puts(IO.ANSI.format([:green, "begin restarting #{host} app"]))

      result =
        "ssh git@#{host} 'compass_admin/bin/compass_admin restart'"
        |> IO.inspect(label: "current execute")
        |> String.to_charlist()
        |> :os.cmd()

      Process.sleep(1000)
      IO.puts(IO.ANSI.format([:green, "#{host} restarted"]))
      IO.puts(result)
    end)
  end
end
