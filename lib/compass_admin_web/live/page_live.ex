defmodule CompassAdminWeb.PageLive do
  use CompassAdminWeb, :live_view
  alias CompassAdmin.Services.CronoCheck

  @impl true
  def mount(_params, _session, socket) do
    {:ok, %{param: processes}} = CronoCheck.list_processes()

    {:ok,
     assign(socket,
       processes: processes,
       modal: false,
       slide_over: false,
       pagination_page: 1
     )}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    case socket.assigns.live_action do
      :index ->
        {:noreply, assign(socket, modal: false, slide_over: false)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-screen overflow-auto dark:bg-gray-900">
      <.container max_width="xl" class="mt-10">
        <.table>
          <.tr>
            <.th>Service Name</.th>
            <.th>Group</.th>
            <.th>Descrption</.th>
            <.th>Status</.th>
            <.th></.th>
          </.tr>

          <%= for {group, sub_processes} <- Enum.group_by(@processes, &(&1["group"])) do %>
            <.tr>
              <.td class="pt-2 pb-0 pl-0">
                <.badge color="primary" label={group} />
              </.td>
            </.tr>
            <%= for process <- sub_processes do %>
              <.tr class={process["group"]}>
                <.td>
                  <%= if process["group"] == process["name"],
                    do: process["name"],
                    else: process["group"] <> ":" <> process["name"] %>
                </.td>
                <.td><%= process["group"] %></.td>
                <.td class="whitespace-nowrap"><%= process["description"] %></.td>
                <.td>
                  <.badge color="success" label={process["statename"]} />
                </.td>
                <.td>
                  <.a to="/admin" label="Comming soon" class="text-primary-600 dark:text-primary-400" />
                </.td>
              </.tr>
            <% end %>
          <% end %>
        </.table>
      </.container>
    </div>
    """
  end

  def handle_info(:update, _, socket) do
    {:ok, %{param: processes}} = CronoCheck.list_processes()
    {:noreply, assign(socket, processes: processes)}
  end
end
