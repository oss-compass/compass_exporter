defmodule CompassAdmin.LogBoardway do
  use Broadway
  require Logger

  alias Broadway.Message
  alias CompassAdmin.StreamProducer

  @apm_config Application.get_env(:compass_admin, :apm, %{})

  @app_pattern ~r/method=(\w+) path=(\/[^\s]*) format=(?<format>[^\s]+) controller=([^\s]+) action=([^\s]+) status=(\d+) allocations=(\d+) duration=(\d+\.\d+) view=(\d+\.\d+) db=(\d+\.\d+) host=([^\s]+) remote_ip=([^\s]+) x_forwarded_for=(.*)/

  @log_meta_pattern ~r/(\w+), \[([^\s]+) (#\d+)\]\s+(\w+)\s+(.*)/

  def start_link(command) do
    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [
        concurrency: 1,
        module: {StreamProducer, command},
        transformer: {StreamProducer, :transform, []}
      ],
      processors: [
        default: [
          concurrency: 10,
          min_demand: 0,
          max_demand: 1
        ]
      ]
    )
  end

  @impl true
  def handle_message(_, %Message{data: data} = message, _) do
    String.split(data, "\n", trim: true)
    |> Enum.map(fn line ->

      [log_path | rest] =
        String.split(line, "|", parts: 2, trim: true) |> Enum.map(&String.trim/1)

      [log_meta | content] =
        String.split(to_string(List.first(rest)), " : ", parts: 2, trim: true) |> Enum.map(&String.trim/1)

      {log_path, content} =
      if length(content) == 0 do
        {log_path, ""}
      else
        {log_path, IO.iodata_to_binary(content)}
      end

      base_document = Map.merge(%{log_path: log_path}, parse_log_meta_line(log_meta))

      document =
        cond do
        String.contains?(log_path, "production") ->
          Map.merge(base_document, parse_production_log_line(content))

        String.contains?(log_path, "sneakers") ->
          Map.merge(base_document, parse_sneakers_log_line(content))

        String.contains?(log_path, "development") ->
          Map.merge(base_document, parse_development_log_line(content))

        true ->
          Map.merge(base_document, %{content: content})
      end

      Finch.build(:post,
        "#{@apm_config[:upstream]}/api/default/default/_json",
        [{"Authorization", "Basic #{@apm_config[:basic_auth]}"}],
        [Jason.encode!(document)]
      ) |> Finch.request(LogFinch)
    end)
    message
  end

  @impl true
  def handle_batch(_, messages, _, _) do
    messages
  end

  def parse_log_meta_line(line) do
    case Regex.scan(@log_meta_pattern, line) do
      [
        [
          _raw,
          short_level,
          datetime,
          rid,
          level,
          extra
        ]
      ] ->
        %{
          short_level: short_level,
          datetime: datetime,
          rid: rid,
          level: level,
          extra: extra
        }
      _ ->
        %{log_meta: line}
    end
  end
  def parse_sneakers_log_line(line), do: %{content: line}
  def parse_production_log_line(line) do
    case Regex.scan(@app_pattern, line) do
      [[_, method, path, format, controller, action, status, allocations, duration, view, db, host, remote_ip, x_forwarded_for]] ->
        %{
          method: method,
          path: path,
          format: format,
          controller: controller,
          action: action,
          status: String.to_integer(status),
          allocations: String.to_integer(allocations),
          duration: String.to_float(duration),
          view: String.to_float(view),
          db: String.to_float(db),
          host: host,
          remote_ip: remote_ip,
          x_forwarded_for: x_forwarded_for
        }

      _ ->
        %{content: line}
    end
  end
  def parse_development_log_line(line), do: parse_production_log_line(line)
end
