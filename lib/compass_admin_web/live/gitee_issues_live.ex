defmodule CompassAdminWeb.GiteeIssuesLive do
  use CompassAdminWeb, :live_view

  alias CompassAdmin.User
  alias ExIndexea.Client
  alias ExIndexea.Config
  alias CompassAdminWeb.Helpers

  @default_size 20
  @default_page 1
  @default_search_mode "full_search"

  require Logger

  @impl true
  def mount(_params, %{"current_user" => current_user}, socket) do
    if User.is_admin?(current_user) do
      {
        :ok,
        socket
        |> assign(:prepare_creator_ids, [])
        |> assign(:can_delete_by_owner_id, false)
        |> assign(:can_delete_by_creator_id, false)
        |> assign(:can_delete_by_creator_docs_count, false)
        |> assign(:loading_delete_by_creator_docs_count, false)
        |> assign(:search_mode, @default_search_mode)
      }
    else
      {:ok, put_flash(socket, :error, "You don't have permissions to access this page.")}
    end
  end

  @impl true
  def handle_params(params, _uri, socket) do
    cached_page = socket.assigns[:meta][:current_page] || @default_page
    cached_search_mode = socket.assigns[:search_mode] || @default_search_mode

    query = Map.get(params, "query") || get_in(params, ["search_field", "query"])
    current_page = (Map.get(params, "page") || cached_page) |> binary_to_integer

    search_mode =
      Map.get(params, "search_mode") || get_in(params, ["search_field", "search_mode"]) ||
        cached_search_mode

    {:noreply,
     list_records(socket, %{
       from: (current_page - 1) * @default_size,
       size: @default_size,
       q: query,
       page: current_page,
       search_mode: search_mode
     })}
  end

  @impl true
  def handle_event(
        "search",
        %{"search_field" => %{"query" => query}},
        socket
      ) do
    {:noreply, push_patch(socket, to: cached_url(socket, query, @default_page))}
  end

  def handle_event("validate", %{"bulk_field" => %{"owner_id" => owner_id}}, socket) do
    {:noreply, assign(socket, :can_delete_by_owner_id, is_number_string(owner_id))}
  end

  def handle_event("validate", %{"bulk_field" => %{"creator_docs_count" => docs_count}}, socket) do
    docs_count = string_to_number(docs_count)

    creator_ids =
      if docs_count > 0 do
        get_in_attempt(socket.assigns[:aggs], ["creator_id", "buckets"], [])
        |> Enum.filter(fn row -> row["doc_count"] >= docs_count end)
        |> Enum.map(fn row -> row["key"] end)
      else
        []
      end

    {:noreply,
     socket
     |> assign(:can_delete_by_creator_docs_count, docs_count > 0)
     |> assign(:prepare_creator_ids, creator_ids)}
  end

  def handle_event("validate", _, socket) do
    {:noreply, socket}
  end

  def handle_event("bulk", %{"bulk_field" => %{"creator_id" => creator_id}}, socket) do
    {:noreply,
     if(is_number_string(creator_id),
       do: bulk_delete(socket, :creator_id, %{creator_id: String.to_integer(creator_id)}),
       else: socket
     )}
  end

  def handle_event("bulk", %{"bulk_field" => %{"owner_id" => owner_id}}, socket) do
    {:noreply,
     if(is_number_string(owner_id),
       do: bulk_delete(socket, :issue_owner_id, %{owner_id: String.to_integer(owner_id)}),
       else: socket
     )}
  end

  def handle_event("bulk", %{"bulk_field" => %{"creator_docs_count" => _}}, socket) do
    if connected?(socket), do: Process.send_after(self(), :bulk, 1000)

    creator_ids = socket.assigns[:prepare_creator_ids] || []

    Enum.map(creator_ids, fn creator_id ->
      Logger.info("delete #{creator_id}")
      bulk_delete(socket, :creator_id, %{creator_id: creator_id})
    end)

    {:noreply,
     socket
     |> put_flash(:info, "Deleted Successfully.")
     |> assign(:loading_delete_by_creator_docs_count, false)
     |> push_patch(to: cached_url(socket))}
  end

  def handle_event("close_modal", _, socket) do
    {:noreply, push_patch(socket, to: cached_url(socket))}
  end

  def handle_event("switch_mode", %{"mode" => mode}, socket) do
    {:noreply, push_patch(socket, to: cached_url(socket, nil, nil, mode))}
  end

  @impl true

  def handle_info(:bulk, socket) do
    {:noreply, assign(socket, :loading_delete_by_creator_docs_count, true)}
  end

  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%= if live_flash(@flash, :error) == nil do %>
      <div class="flex flex-col overflow-auto mb-2">
        <form phx-change="search" class="mb-2 float-left">
          <span>
            <%= text_input(:search_field, :query,
              placeholder: "Search by keywords",
              autofocus: true,
              "phx-debounce": "300",
              value: @meta[:query]
            ) %>
            <%= hidden_input(:search_field, :search_mode, value: @search_mode) %>

            <.button
              link_type="live_patch"
              to={"/admin/gitee/issues/bulk?page=#{@meta[:current_page]}&query=#{@meta[:query]}&search_mode=#{@search_mode}"}
              label="Bulk"
            />
          </span>
        </form>
        <.button
          class="float-right w-48"
          phx-click="switch_mode"
          phx-value-mode={if @search_mode == "open_search", do: "full_search", else: "open_search"}
          label={if @search_mode == "open_search", do: "Open Search Mode", else: "Full Fields Mode"}
        />
        <%= if @live_action == :bulk do %>
          <.modal max_width="lg" title="Bulk Operations">
            <form phx-submit="bulk" phx-change="validate" class="mb-2 float-left">
              <.p>Delete by owner_id :</.p>
              <%= text_input(:bulk_field, :owner_id,
                placeholder: "input the owner_id",
                autofocus: true,
                "phx-debounce": "300"
              ) %>
              <.button label="Confirm" disabled={!@can_delete_by_owner_id} />
            </form>
            <%= if @aggs != %{} do %>
              <form phx-submit="bulk" phx-change="validate" class="mb-2 float-left">
                <.p>Delete by creator_id with docs count:</.p>
                <%= text_input(:bulk_field, :creator_docs_count,
                  placeholder: "input the docs count",
                  autofocus: true,
                  "phx-debounce": "300"
                ) %>
                <.button
                  label="Confirm"
                  disabled={!@can_delete_by_creator_docs_count}
                  type="submit"
                  loading={@loading_delete_by_creator_docs_count}
                  data-confirm={"Are you sure delete docs with creator_ids: [#{Enum.join(@prepare_creator_ids, ",")}] ?"}
                />
              </form>

              <%= for header <- Map.keys(@aggs) do %>
                <.table>
                  <.tr>
                    <.th><%= header %></.th>
                    <.th>Docs Count</.th>
                  </.tr>

                  <%= for record <- @aggs[header]["buckets"] do %>
                    <.tr>
                      <.td class="text-sm font-medium text-gray-500 truncate hover:text-clip">
                        <%= Helpers.truncate(record["key"]) %>
                      </.td>
                      <.td class="text-sm font-medium text-gray-500 truncate hover:text-clip">
                        <%= record["doc_count"] %>
                      </.td>
                    </.tr>
                  <% end %>
                </.table>
              <% end %>
            <% end %>

            <div class="flex justify-end mt-32 -ml-10">
              <.button color="white" phx-click="close_modal" label="Close" />
            </div>
          </.modal>
        <% end %>
        <text><%= "About #{@meta[:total]} records in the results" %></text>
        <.table class="mb-2">
          <.tr>
            <%= for header <- @headers do %>
              <.th><%= header %></.th>
            <% end %>
          </.tr>

          <%= for record <- @records do %>
            <.tr>
              <%= for header <- @headers do %>
                <.td class="text-sm font-medium text-gray-500 truncate hover:text-clip">
                  <%= Helpers.truncate(record[header]) %>
                </.td>
              <% end %>
            </.tr>
          <% end %>
        </.table>
      </div>
      <div class="flex justify-center">
        <.pagination
          link_type="live_patch"
          path={
            fn page ->
              "/admin/gitee/issues?page=#{page}&query=#{@meta[:query]}&search_mode=#{@search_mode}"
            end
          }
          current_page={@meta[:current_page]}
          total_pages={@meta[:total_pages]}
        />
      </div>
    <% end %>
    """
  end

  defp config(key) do
    Application.get_env(:ex_indexea, key)
  end

  def list_records(socket, params) do
    query = get_in(params, [:q])
    current_page = get_in(params, [:page]) || @default_page
    search_mode = get_in(params, [:search_mode]) || @default_search_mode

    case do_list_recods(search_mode, params) do
      {200, data, _resp} ->
        total = get_in(data, ["hits", "total", "value"]) || 0
        hits = get_in(data, ["hits", "hits"]) || []
        aggs = get_in(data, ["aggregations"]) || %{}

        get_fields = fn row ->
          base = Map.get(row, "_source") || Map.get(row, "fields") || %{}

          for {k, v} <- base,
              into: %{},
              do: {k, if(is_list(v) && length(v) == 1, do: List.first(v), else: v)}
        end

        records =
          Enum.map(hits, fn hit ->
            hit
            |> get_fields.()
            |> FlattenMap.flatten()
          end)

        headers = if List.first(records), do: Map.keys(List.first(records)), else: []

        assign(socket,
          records: records,
          headers: headers,
          aggs: aggs,
          meta: %{
            current_page: current_page,
            total_pages: ceil(total / @default_size),
            query: query,
            total: total
          },
          search_mode: search_mode
        )

      {_, reason, _response} ->
        put_flash(socket, :error, "#{inspect(reason)}")
    end
  end

  defp do_list_recods("open_search", params) do
    ExIndexea.Queries.search_query(client(), Config.app(), config(:issue_search_id), params)
  end

  defp do_list_recods(_, params) do
    ExIndexea.Records.list(client(), Config.app(), config(:issue_index), params)
  end

  defp bulk_delete(socket, key, params) do
    case ExIndexea.Records.delete_by_query(
          client(),
          Config.app(),
          config(:issue_index),
          config(key),
          params
        ) do
      {200, _data, _resp} ->
        socket
        |> put_flash(:info, "Deleted Successfully.")
        |> push_patch(to: cached_url(socket))

      {_, reason, _response} ->
        socket
        |> put_flash(:error, "#{inspect(reason)}")
        |> push_patch(to: cached_url(socket))
    end
  end

  defp is_number_string(text) do
    case Integer.parse(text) do
      {_int, ""} ->
        true

      _ ->
        false
    end
  end

  defp string_to_number(text) do
    case Integer.parse(text) do
      {int, ""} ->
        int

      _ ->
        0
    end
  end

  def get_in_attempt(data, keys, default) do
    case get_in(data, keys) do
      nil -> default
      result -> result
    end
  end

  defp binary_to_integer(nil), do: 0
  defp binary_to_integer(binary_or_int) when is_number(binary_or_int), do: binary_or_int

  defp binary_to_integer(binary_or_int) when is_binary(binary_or_int),
    do: String.to_integer(binary_or_int)

  defp cached_url(socket, query \\ nil, page \\ nil, search_mode \\ nil, suffix \\ "") do
    query = query || socket.assigns[:meta][:query]
    cached_page = page || socket.assigns[:meta][:current_page] || @default_page
    search_mode = search_mode || socket.assigns[:search_mode] || @default_search_mode

    "/admin/gitee/issues/#{suffix}?page=#{cached_page}&query=#{query}&search_mode=#{search_mode}"
  end

  defp client() do
    Client.new(%{access_token: Config.access_token()})
  end
end
