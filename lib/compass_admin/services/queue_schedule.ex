defmodule CompassAdmin.Services.QueueSchedule do
  @config Application.get_env(:compass_admin, __MODULE__, %{})

  def start() do
    queues = @config[:queues] || []
    worker_num = @config[:worker_num] || 16
    minor_num = @config[:minor_num] || 2000
    max_group = @config[:max_group] || 4
    scoop = Application.app_dir(:compass_admin, "priv/bin/scoop")

    {:ok, channel} = AMQP.Application.get_channel(:compass_chan)
    Enum.each(queues, fn queue_mapping ->
      with [major_queue: major_name, minior_queue: minor_name, pending_queue: pending_name] <- queue_mapping do
        {:ok, major_queue} = AMQP.Queue.declare(channel, major_name, [durable: true])
        major_count = major_queue.message_count |> IO.inspect(label: "Major queue")

        {:ok, minor_queue} = AMQP.Queue.declare(channel, minor_name, [durable: true])
        minor_count = minor_queue.message_count |> IO.inspect(label: "Minor queue")

        {:ok, pending_queue} = AMQP.Queue.declare(channel, pending_name, [durable: true])
        pending_count = pending_queue.message_count |> IO.inspect(label: "Pending queue")

        if major_count > (worker_num * max_group) do
          args = build_args(major_name, minor_name, major_count - (worker_num * max_group))
          options = [stderr_to_stdout: true, into: IO.stream(:stdio, :line)]
          case System.cmd(scoop, args, options) do
            {output, 0} -> {:ok, output} |> IO.inspect(label: "Moving to #{minor_name}")
            {err, code} -> {:error, err, code}
          end
        end

        if major_count < worker_num && minor_count > 0 do
          args = build_args(minor_name, major_name, worker_num - major_count)
          options = [stderr_to_stdout: true, into: IO.stream(:stdio, :line)]
          case System.cmd(scoop, args, options) do
            {output, 0} -> {:ok, output} |> IO.inspect(label: "Moving to #{major_name}")
            {err, code} -> {:error, err, code}
          end
        end

        if minor_count < minor_num && pending_count > 0 do
          args = build_args(pending_name, minor_name, worker_num)
          options = [stderr_to_stdout: true, into: IO.stream(:stdio, :line)]
          case System.cmd(scoop, args, options) do
            {output, 0} -> {:ok, output} |> IO.inspect(label: "Moving to #{minor_name}")
            {err, code} -> {:error, err, code}
          end
        end
      end
    end)
  end

  def build_args(from, to, count) do
    [
      "-from",
      "#{from}",
      "-to",
      "#{to}",
      "-username",
      "#{@config[:username]}",
      "-password",
      "#{@config[:password]}",
      "-hostname",
      @config[:host],
      "-count",
      to_string(count),
      "-vvv"
    ]
  end
end
