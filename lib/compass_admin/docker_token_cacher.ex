defmodule CompassAdmin.DockerTokenCacher do
  use GenServer
  @config Application.get_env(:compass_admin, CompassAdmin.Services.ExportMetrics, %{})

  defmodule Token do
    @enforce_keys [:token, :expires_at]
    @refresh_lead_time_s 30 # Refresh 30 seconds before expiry
    defstruct token: nil, expires_at: nil

    def valid?(%__MODULE__{} = token) do
      refresh_time = DateTime.add(DateTime.utc_now(), -@refresh_lead_time_s, :second)
      DateTime.compare(token.expires_at, refresh_time) == :gt
    end
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def get(conn) do
    GenServer.call(__MODULE__, {:get, conn})
  end

  @impl true
  def init(_) do
    {:ok, nil}
  end

  @impl true
  def handle_call({:get, conn}, _from, nil) do
    get_token(conn, %{})
  end

  def handle_call({:get, conn}, _from, state) do
    token = Map.get(state, extract_key(conn))
    if token && Token.valid?(token) do
        {:reply, token, state}
    else
      get_token(conn, state)
    end
  end

  defp extract_key(conn) do
    [_|rest] = conn.path_info
    path = if rest, do: Enum.join(rest, "/"), else: ""
    cond do
      route = Regex.named_captures(~r/(?<namespace>[^\s]+)\/manifests\/.*?/, path) ->
        route["namespace"]
      route = Regex.named_captures(~r/(?<namespace>[^\s]+)\/blobs\/.*?/, path) ->
        route["namespace"]
      route = Regex.named_captures(~r/(?<namespace>[^\s]+)\/tags\/.*?/, path) ->
        route["namespace"]
      true ->
        ""
    end
  end

  defp get_token(conn, state) do
    key = extract_key(conn)
    case fetch_token(key) do
      {:ok, token, expiration} ->
        new_token = %Token{token: token, expires_at: DateTime.add(DateTime.utc_now(), expiration)}
        {:reply, new_token, Map.put(state, key, new_token)}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  defp fetch_token(key) do
    # Replace this with your actual token fetching logic
    # Example using HTTPoison
    base = "https://auth.docker.io/token?service=registry.docker.io"

    url =
    if String.length(key) > 1 do
      "#{base}&scope=repository:#{key}:pull"
    else
      base
    end

    case HTTPoison.get(url, [], [proxy: @config[:proxy]]) do
      {:ok, %{body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"access_token" => token, "expires_in" => expires_in}} ->
            {:ok, token, expires_in}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end
end
