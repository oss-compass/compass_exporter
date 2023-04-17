defmodule CompassAdmin.Services.ExportMetrics do
  @num_partitions 20
  @batch_size 10000
  @max_timeout 15_000
  @report_index "compass_metric_model_activity"
  @config Application.get_env(:compass_admin, __MODULE__, %{})

  def start() do
    Enum.each([gitee: :raw, github: :raw, gitee: :enriched, github: :enriched], fn {origin, type} ->
      with {:ok, %{aggregations: %{"distinct" => %{value: value}}}} <-
             Snap.Search.search(
               CompassAdmin.Cluster,
               "#{origin}-repo_#{type}",
               %{
                 size: 0,
                 aggs: %{distinct: %{cardinality: %{field: :origin}}}
               }
             ) do
        Metrics.CompassInstrumenter.observe(:report_stats, value, [origin, type, :repo])
      end
    end)

    Enum.flat_map(0..(@num_partitions - 1), fn partition ->
      with {:ok, %{aggregations: %{"distinct_values" => %{buckets: buckets}}}} <-
             Snap.Search.search(
               CompassAdmin.Cluster,
               @report_index,
               %{
                 size: 0,
                 aggs: %{
                   distinct_values: %{
                     terms: %{
                       field: "label.keyword",
                       size: @batch_size,
                       include: %{
                         partition: partition,
                         num_partitions: @num_partitions
                       },
                       order: %{_term: :asc}
                     }
                   }
                 }
               }
             ) do
        Enum.map(buckets, & &1["key"])
      end
    end)
    |> Enum.group_by(fn label ->
      if is_url?(label) do
        if String.contains?(label, "gitee.com"), do: "gitee", else: "github"
      else
        "community"
      end
    end)
    |> Enum.map(fn {origin, list} ->
      value = length(list)

      Metrics.CompassInstrumenter.observe(:report_stats, value, [
        origin,
        :finished,
        if(origin == "community", do: origin, else: :repo)
      ])

      {origin, value}
    end)

    Metrics.CompassInstrumenter.observe(:token_stats, length(@config[:github_tokens]), [:count])

    token_stats =
      @config[:github_tokens]
      |> Enum.with_index()
      |> Enum.chunk_every(4)
      |> Enum.map(fn tokens_with_index ->
        Enum.map(tokens_with_index, fn {token, index} ->
          Task.async(fn ->
            case Finch.build(
                   :get,
                   "https://api.github.com/rate_limit",
                   [{"Content-Type", "application/json"}, {"Authorization", "Bearer #{token}"}],
                   nil,
                   proxy: @config[:proxy]
                 )
                 |> Finch.request(CompassFinch) do
              {:ok, %{body: body}} ->
                case Jason.decode(body) do
                  {:ok,
                   %{
                     "rate" => %{
                       "limit" => limit,
                       "remaining" => remaining,
                       "reset" => reset,
                       "used" => used
                     }
                   }} ->
                    Metrics.CompassInstrumenter.observe(:target_token, limit, ["token-#{index}", :limit])
                    Metrics.CompassInstrumenter.observe(:target_token, remaining, ["token-#{index}", :remaining])
                    Metrics.CompassInstrumenter.observe(:target_token, used, ["token-#{index}", :used])
                    Metrics.CompassInstrumenter.observe(:target_token, reset, ["token-#{index}", :reset])
                    {limit, remaining, used, reset}

                  _ ->
                    {0, 0, 0, 0}
                end

              _ ->
                {0, 0, 0, 0}
            end
          end)
        end)
        |> Task.await_many(@max_timeout)
      end)

    token_stats = List.flatten(token_stats)

    token_sum = Enum.sum(Enum.map(token_stats, &elem(&1, 0)))
    token_remaining = Enum.sum(Enum.map(token_stats, &elem(&1, 1)))
    token_used = Enum.sum(Enum.map(token_stats, &elem(&1, 2)))
    Metrics.CompassInstrumenter.observe(:token_stats, token_sum, [:sum])
    Metrics.CompassInstrumenter.observe(:token_stats, token_remaining, [:remaining])
    Metrics.CompassInstrumenter.observe(:token_stats, token_used, [:used])

    Metrics.CompassInstrumenter.observe(:token_stats, token_used / (token_sum + 1), [
      :used_percentage
    ])
  end

  defp is_url?(str) do
    case URI.parse(str) do
      %URI{scheme: scheme, host: host} when scheme in ["http", "https"] and not is_nil(host) ->
        true

      _ ->
        false
    end
  end
end
