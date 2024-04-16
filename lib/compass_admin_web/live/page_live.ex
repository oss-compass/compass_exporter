defmodule CompassAdminWeb.PageLive do
  use CompassAdminWeb, :live_view
  alias CompassAdmin.Services.CronoCheck

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Process.send_after(self(), :refresh, 5000)
    processes_map = CronoCheck.list_processes()

    {:ok, assign(socket, processes: processes_map)}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    case socket.assigns.live_action do
      :index ->
        {:noreply, assign(socket, action: :index)}
    end
  end

  @impl true
  def handle_info(:refresh, socket) do
    Process.send_after(self(), :refresh, 5000)
    processes_map = CronoCheck.list_processes()
    {:noreply, assign(socket, processes: processes_map)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.table>
      <.tr>
        <.th>Node</.th>
        <.th>Service Name</.th>
        <.th>Descrption</.th>
        <.th>Status</.th>
      </.tr>
      <%= for {node, processes} <- @processes do %>
        <.tr>
          <.td class="pt-2 pb-0 pl-0">
            <.badge color="primary" label={node} />
          </.td>
        </.tr>
        <%= for {_group, sub_processes} <- Enum.group_by(processes, &(&1["group"])) do %>
          <%= for process <- sub_processes do %>
            <.tr class={process["group"]}>
              <.td class="whitespace-nowrap"><%= node %></.td>
              <.td>
                <%= if process["group"] == process["name"],
                  do: process["name"],
                  else: process["group"] <> ":" <> process["name"] %>
              </.td>
              <.td class="whitespace-nowrap"><%= process["description"] %></.td>
              <.td>
                <.badge color={state_color(process["statename"])} label={process["statename"]} />
              </.td>
            </.tr>
          <% end %>
        <% end %>
      <% end %>
    </.table>
    """
  end

  defp state_color("RUNNING"), do: "success"
  defp state_color(_), do: "danger"
end
