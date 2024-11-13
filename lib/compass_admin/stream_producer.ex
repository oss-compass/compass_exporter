defmodule CompassAdmin.StreamProducer do
  # See https://hexdocs.pm/broadway/custom-producers.html#example
  use GenStage

  alias Broadway.Message

  # Broadway will not call the child_spec/1 or start_link/1 function of the producer.
  # That's because Broadway wraps the producer to augment it with extra features.
  def start_link(command) do
    GenStage.start_link(__MODULE__, command)
  end

  # When Broadway starts, the GenStage.init/1 callback will be invoked w the given opts.
  def init(command) do
    {:producer, Exile.stream!(["bash", "-c"] ++ command, exit_timeout: 1000)}
  end

  def handle_demand(demand, stream) when demand > 0 do
    {head, tail} = StreamSplit.take_and_drop(stream, demand)
    {:noreply, head, tail}
  end

  def handle_info(_, state) do
    {:noreply, [], state}
  end

  # Not part of the behavior, but Broadway req's that we translate the genstage events
  # into Broadway msgs
  def transform(event, _opts) do
    %Message{
      data: event,
      acknowledger: {__MODULE__, :ack_id, :ack_data}
    }
  end

  def ack(:ack_id, _successful, _failed) do
    # Write ack code here
  end
end
