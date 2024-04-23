defmodule CompassAdminWeb.DockerServicesLive do
  use CompassAdminWeb, :live_view
  alias CompassAdmin.Services.Docker

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Process.send_after(self(), :refresh, 5000)
    processes_map = Docker.list_processes()

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
    processes_map = Docker.list_processes()
    {:noreply, assign(socket, processes: processes_map)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.table>
      <.tr>
        <.th>Node</.th>
        <.th>ID</.th>
        <.th>Image</.th>
        <.th>Names</.th>
        <.th>Descrption</.th>
        <.th>Status</.th>
      </.tr>
      <%= for {node, processes} <- @processes do %>
        <.tr>
          <.td class="pt-2 pb-0 pl-0">
            <.badge color="primary" label={node} />
          </.td>
        </.tr>
        <%= for process <- processes do %>
          <.tr>
            <.td class="whitespace-nowrap"><%= node %></.td>
            <.td class="whitespace-nowrap"><%= process["ID"] %></.td>
            <.td><%= process["Image"] %></.td>
            <.td><%= process["Names"] %></.td>
            <.td><%= "Created at #{process["CreatedAt"]}; #{process["Status"]}" %></.td>
            <.td>
              <.badge color={state_color(process["State"])} label={process["State"]} />
            </.td>
          </.tr>
        <% end %>
      <% end %>
    </.table>
    """
  end

  defp state_color("running"), do: "success"
  defp state_color(_), do: "danger"
end
