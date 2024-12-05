defmodule CompassAdminWeb.Components.DeploymentPage do
  use Phoenix.Component
  import PetalComponents.{Container, Alert, Table, Badge, Button}

  def deployment_page(assigns) do
    ~H"""
    <.container max_width="full">
      <div class="container mx-auto px-4">
        <.alert color="info">
          Deployments
        </.alert>
        <div class="grid grid-cols-3 gap-4">
          <div class="col-span-2 bg-white shadow-md rounded-lg p-4 max-h-screen">
            <h2 class="text-xl pb-2"><%= @title %></h2>
            <div class="overflow-auto h-4/5" phx-hook="LogScrollHook" id="log-scroll-hook">
              <ul>
                <%= for log <- Enum.reverse(@agent_state.logs) do %>
                  <li class="text-nowrap text-gray-400 pb-1 pt-1"><%= log %></li>
                <% end %>
              </ul>
            </div>
          </div>

          <div class="bg-white shadow-md rounded-lg p-4">
            <h2 class="text-xl font-bold mb-2">Last Trigger</h2>
            <%= if @last_trigger != nil do %>
              <.table>
                <.tr>
                  <.td>
                    <.user_inner_td
                      avatar_assigns={%{src: @last_trigger.avatar_url}}
                      label={@last_trigger.nickname}
                      sub_label={Timex.from_now(@agent_state.last_triggered_at)}
                    />
                    <span>
                      Last triggered result:
                      <a
                        href="#"
                        data-twe-toggle="tooltip"
                        title={format_result(@agent_state.last_triggered_result)}
                      >
                        <.badge
                          color={format_state(@agent_state.last_triggered_result)}
                          label={format_label(@agent_state.last_triggered_result)}
                        />
                      </a>
                    </span>
                  </.td>
                </.tr>
              </.table>
            <% else %>
              <.alert with_icon color="info" label="No trigger records now" />
            <% end %>

            <h2 class="text-xl font-bold mt-2 mb-2">Last Deploy</h2>
            <%= if @last_deployer != nil do %>
              <.table>
                <.tr>
                  <.td>
                    <.user_inner_td
                      avatar_assigns={%{src: @last_deployer.avatar_url}}
                      label={@last_deployer.nickname}
                      sub_label={Timex.from_now(@agent_state.last_deploy_at)}
                    />
                    <span>
                      Last deploy result:
                      <a
                        href="#"
                        data-twe-toggle="tooltip"
                        title={format_result(@agent_state.last_deploy_result)}
                      >
                        <.badge
                          color={format_state(@agent_state.last_deploy_result)}
                          label={format_label(@agent_state.last_deploy_result)}
                        />
                      </a>
                    </span>
                  </.td>
                </.tr>
              </.table>
            <% else %>
              <.alert with_icon color="info" label="No deploy records now" />
            <% end %>
            <div class="flex pt-4 justify-center">
              <.button
                phx-click="deploy"
                color="primary"
                label="One Click Deploy"
                loading={@agent_state.state != :ok}
                disabled={@agent_state.state != :ok || !@can_deploy}
              />
            </div>
          </div>
        </div>
      </div>
    </.container>
    """
  end

  defp format_state(result) do
    case result do
      {:ok, "processing"} -> "info"
      {:ok, _} -> "success"
      {:error, _} -> "danger"
      _ -> "warning"
    end
  end

  defp format_label(result) do
    case result do
      {:ok, "processing"} -> "processing"
      {:ok, _} -> "success"
      {:error, _} -> "error"
      _ -> "unknown"
    end
  end

  defp format_result(result) do
    case result do
      {:ok, "processing"} -> "Processing"
      {:ok, message} -> message
      {:error, reason} -> inspect(reason)
      _ -> "Unknown result"
    end
  end
end
