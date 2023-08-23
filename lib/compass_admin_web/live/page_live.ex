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
        <.tabs underline>
          <.tab underline is_active to="/">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              fill="none"
              viewBox="0 0 24 24"
              stroke-width="1.5"
              stroke="currentColor"
              class="w-6 h-6"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M11.42 15.17L17.25 21A2.652 2.652 0 0021 17.25l-5.877-5.877M11.42 15.17l2.496-3.03c.317-.384.74-.626 1.208-.766M11.42 15.17l-4.655 5.653a2.548 2.548 0 11-3.586-3.586l6.837-5.63m5.108-.233c.55-.164 1.163-.188 1.743-.14a4.5 4.5 0 004.486-6.336l-3.276 3.277a3.004 3.004 0 01-2.25-2.25l3.276-3.276a4.5 4.5 0 00-6.336 4.486c.091 1.076-.071 2.264-.904 2.95l-.102.085m-1.745 1.437L5.909 7.5H4.5L2.25 3.75l1.5-1.5L7.5 4.5v1.409l4.26 4.26m-1.745 1.437l1.745-1.437m6.615 8.206L15.75 15.75M4.867 19.125h.008v.008h-.008v-.008z"
              />
            </svg>
            Services List
          </.tab>
        </.tabs>
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
