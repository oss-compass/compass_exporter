defmodule CompassAdminWeb.ConfigurationLive do
  use CompassAdminWeb, :live_view

  alias CompassAdmin.User
  alias CompassAdmin.RiakPool
  alias CompassAdmin.Agents.ExecAgent
  import CompassAdmin.Utils, only: [apm_call: 3]

  @max_lines 5000
  @bucket "configures"

  @impl true
  def mount(_params, %{"current_user" => current_user}, socket) do
    if current_user.role_level >= User.backend_dev_role() do
      {:ok,
       socket
       |> assign(:logs, ["Welcome to use OSS Compass Admin Configurations.\n"])
       |> assign(:hidden, false)
       |> assign(:staged, false)
       |> assign(:commit_message, "")
       |> assign(:current_user, current_user)
       |> assign(:changeset, to_form(%{}))}
    else
      {:ok,
       socket
       |> assign(:hidden, true)
       |> put_flash(:error, "You don't have permissions to access this page.")}
    end
  end

  @impl true
  def handle_params(_params, uri, socket) do
    action = socket.assigns.live_action
    action = if configurations(action), do: action, else: :nginx_config
    config_path = action |> configurations()
    content = apm_call(File, :read!, [config_path])
    current_path = URI.parse(uri).path

    {:noreply,
     socket
     |> assign(:title, to_string(action) |> String.upcase() |> String.replace("_", " "))
     |> assign(:current_path, current_path)
     |> assign(:logs, recent_logs(config_path))
     |> assign(:config_path, config_path)
     |> assign(:original_content, content)
     |> assign(:content, content)}
  end

  @impl true
  def handle_event("stage", %{"content" => content}, socket) do
    ori_content_hash_obj =
      "$(echo -e '#{String.replace(socket.assigns.original_content, "'", "\x27")}' | git hash-object -w --stdin)"

    new_content_hash_obj =
      "$(echo -e '#{String.replace(content, "'", "\x27")}' | git hash-object -w --stdin)"

    config_dir =
      socket.assigns.config_path
      |> Path.dirname()

    diff_command = "cd #{config_dir} && git diff #{ori_content_hash_obj} #{new_content_hash_obj}"

    case apm_call(ExecAgent, :shell_exec, [diff_command]) do
      {:ok, result} ->
        {:noreply,
         socket
         |> assign(:staged, true)
         |> assign(:staged_content, content)
         |> assign(:content, result)
         |> append_log("staged new changes")
         |> push_event("update-editor", %{content: result})
         |> push_event("set-read-only", %{value: true})}

      {:error, exit_status, message} ->
        {:noreply,
         socket
         |> put_flash(:error, "Exit with #{exit_status}, reason: #{message}.")}
    end
  end

  @impl true
  def handle_event("validate", %{"_target" => ["content"], "content" => content}, socket) do
    {:noreply, assign(socket, :content, content)}
  end

  @impl true
  def handle_event(
        "validate",
        %{"_target" => ["commit_message"], "commit_message" => commit_message},
        socket
      ) do
    {:noreply, assign(socket, :commit_message, commit_message)}
  end

  @impl true
  def handle_event("reset", _params, socket) do
    {:noreply,
     socket
     |> assign(:content, socket.assigns.original_content)
     |> append_log("reset unstaged changes")
     |> push_event("update-editor", %{content: socket.assigns.original_content})}
  end

  @impl true
  def handle_event("revert", _params, socket) do
    {:noreply,
     socket
     |> assign(:content, socket.assigns.staged_content)
     |> assign(:staged, false)
     |> append_log("revert staged new changes")
     |> push_event("update-editor", %{content: socket.assigns.staged_content})
     |> push_event("set-read-only", %{value: false})}
  end

  @impl true
  def handle_event("commit", _params, socket) do
    config_path = socket.assigns.config_path
    staged_content = socket.assigns.staged_content
    commit_message = socket.assigns.commit_message
    current_path = socket.assigns.current_path
    current_user = socket.assigns.current_user
    config_dir = Path.dirname(config_path)
    apm_call(File, :write!, [config_path, staged_content])

    [execute: execute] = Application.fetch_env!(:compass_admin, __MODULE__)

    final_execute =
      execute
      |> String.replace("{config_dir}", config_dir)
      |> String.replace("{config_path}", config_path)
      |> String.replace("{username}", current_user.name)
      |> String.replace("{useremail}", current_user.email)
      |> String.replace("{commit_message}", commit_message)

    case apm_call(ExecAgent, :shell_exec, [final_execute]) do
      {:ok, result} ->
        {:noreply,
         socket
         |> append_log("committed new changes")
         |> append_log(result)
         |> put_flash(:info, "Updated Successfully.")
         |> redirect(to: current_path)}

      {:error, exit_status, message} ->
        {:noreply,
         socket
         |> put_flash(:error, "Exit with #{exit_status}, reason: #{message}.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%= if !@hidden do %>
      <.container max_width="full">
        <.h2><%= @title %></.h2>
        <div class="grid grid-cols-3 gap-4">
          <div class="overflow-y h-2/3 col-span-2" id="editor" phx-update="ignore"></div>

          <.form :let={f} for={@changeset} phx-submit="stage" phx-change="validate">
            <.textarea
              id="editdata"
              form={f}
              field={:content}
              value={@content}
              phx-hook="EditorFormHook"
              class="hidden"
            />

            <.form_field_error form={f} field={:content} class="mt-1" />
            <div class="grid grid-cols-subgrid gap-4 col-span-1 grid-rows-2 max-h-fit">
              <div class="grid grid-cols-1 gap-4 h-16">
                <%= if !@staged do %>
                  <.button
                    type="button"
                    color="white"
                    label="Reset"
                    phx-click="reset"
                    disabled={@content == @original_content}
                  />
                  <.button color="primary" label="Stage" disabled={@content == @original_content} />
                <% end %>
                <%= if @staged do %>
                  <.form_field
                    type="textarea"
                    form={f}
                    field={:commit_message}
                    placeholder="Commit Message"
                  />
                  <.button type="button" color="white" label="Revert" phx-click="revert" />
                  <.button
                    type="button"
                    color="primary"
                    label="Commit"
                    phx-click="commit"
                    phx-disable-with="Committing..."
                    disabled={@commit_message == ""}
                  />
                <% end %>
              </div>
              <div class="grid grid-cols-1 gap-4">
                <hr />
                <.h4>Recent Logs</.h4>
                <div class="grid grid-cols-1 gap-4 overflow-auto h-80">
                  <ul>
                    <%= for log <- Enum.reverse(@logs) do %>
                      <li class="text-nowrap text-gray-400 text-xs pb-1 pt-1"><%= log %></li>
                    <% end %>
                  </ul>
                </div>
              </div>
            </div>
          </.form>
        </div>
      </.container>
    <% end %>
    """
  end

  defp recent_logs(config) do
    with cached <- Riak.find(RiakPool.conn, @bucket, "compass:admin:#{config}:logs") do
      if cached != nil, do: :erlang.binary_to_term(cached), else: []
    end || []
  end

  defp save_logs(config, logs) do
    cached =
      Riak.Object.create(
        bucket: @bucket,
        key: "compass:admin:#{config}:logs",
        data: :erlang.term_to_binary(logs)
      )
    Riak.put(RiakPool.conn, cached)
  end

  defp append_log(socket, log) do
    now = Timex.now() |> Timex.format!("%Y-%m-%d %H:%M:%S", :strftime)
    user = socket.assigns.current_user
    new_logs = ["[#{now}] [#{user.name}] #{log}" | Enum.take(socket.assigns.logs, @max_lines)]
    save_logs(socket.assigns.config_path, new_logs)
    assign(socket, :logs, new_logs)
  end

  defp configurations(key) do
    configurations()[key]
  end

  defp configurations() do
    Application.get_env(:compass_admin, :configurations, %{})
  end
end
