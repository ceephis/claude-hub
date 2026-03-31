defmodule HubWeb.ProjectCard do
  use Phoenix.Component

  # ---------------------------------------------------------------------------
  # Full card (leaf level)
  # ---------------------------------------------------------------------------

  attr :project,       :map,    required: true
  attr :group_options, :list,   default: []
  attr :committing,    :string, default: nil

  def project_card(assigns) do
    ~H"""
    <div
      id={"card-#{@project.folder}"}
      class="bg-gray-900 border border-gray-800 rounded-xl p-5 flex flex-col gap-3 hover:border-gray-600 transition-colors"
    >
      <div class="flex items-start justify-between gap-2">
        <h3 class="text-base font-semibold leading-tight">{@project.name}</h3>
        <div class="flex items-center gap-1.5 shrink-0">
          <span class={["text-xs font-medium px-2 py-0.5 rounded-full whitespace-nowrap", status_color(@project.status_key)]}>
            {status_emoji(@project.status_key)} {status_label(@project.status)}
          </span>
          <%= if length(@group_options) > 0 do %>
            <div class="relative w-6 h-5" title="Move to group">
              <span class="absolute inset-0 flex items-center justify-center text-gray-500 hover:text-gray-300 text-sm pointer-events-none">⇄</span>
              <form phx-change="move_card" class="absolute inset-0">
                <input type="hidden" name="folder" value={@project.folder} />
                <select name="to_group_id" class="absolute inset-0 opacity-0 cursor-pointer w-full h-full text-xs">
                  <option value="">Move to...</option>
                  <option value="uncategorized">— Uncategorized —</option>
                  <%= for {id, name, depth} <- @group_options do %>
                    <option value={id}>{indent(depth)}{name}</option>
                  <% end %>
                </select>
              </form>
            </div>
          <% end %>
        </div>
      </div>

      <%= if @project.live_url do %>
        <p class="text-xs text-blue-400">{@project.live_url}</p>
      <% end %>

      <%= if @project.tasks_total > 0 do %>
        <div>
          <div class="flex justify-between text-xs text-gray-400 mb-1">
            <span>{@project.tasks_done} of {@project.tasks_total} tasks</span>
            <span class="font-mono">{@project.progress}%</span>
          </div>
          <div class="w-full bg-gray-800 rounded-full h-2">
            <div
              class={["h-2 rounded-full transition-all", progress_color(@project.progress)]}
              style={"width: #{@project.progress}%"}
            />
          </div>
        </div>
      <% end %>

      <%= if @project.next_action do %>
        <p class="text-sm text-gray-300 leading-snug line-clamp-2">
          <span class="text-gray-500 text-xs">Next: </span>{@project.next_action}
        </p>
      <% end %>

      <div class="text-xs text-gray-500 space-y-0.5 mt-auto">
        <p>Started {format_date(@project.started)} · {@project.days_active}d active</p>
        <p class="truncate">{@project.stack}</p>
      </div>

      <div class="flex gap-2">
        <button
          phx-click="open_in_claude"
          phx-value-folder={@project.folder}
          phx-value-path={@project.path}
          phx-value-name={@project.name}
          class="flex-1 bg-indigo-600 hover:bg-indigo-500 active:bg-indigo-700 text-white text-sm font-medium py-2 rounded-lg transition-colors cursor-pointer"
        >
          Open in Claude
        </button>
        <a
          href={"/status-pdf/#{@project.folder}"}
          title="Download STATUS.md as PDF"
          class="flex-1 bg-gray-800 hover:bg-blue-900 active:bg-blue-800 text-blue-400 text-sm font-medium py-2 rounded-lg transition-colors border border-gray-700 text-center"
        >
          📄 PDF
        </a>
      </div>

      <div class="flex gap-2">
        <%= if @committing == @project.folder do %>
          <form
            phx-submit="commit_and_push"
            phx-keydown="cancel_commit"
            phx-key="Escape"
            class="flex flex-1 gap-1"
          >
            <input type="hidden" name="folder" value={@project.folder} />
            <input type="hidden" name="path" value={@project.git_path} />
            <input type="hidden" name="name" value={@project.name} />
            <input
              type="text"
              name="message"
              placeholder="Commit message..."
              autofocus
              class="flex-1 bg-gray-700 border border-indigo-500 text-white text-xs rounded-lg px-2 py-1.5 outline-none min-w-0"
            />
            <button type="submit" class="text-green-400 hover:text-green-300 text-sm px-1.5">✓</button>
            <button type="button" phx-click="cancel_commit" class="text-gray-500 hover:text-gray-300 text-sm px-1">✕</button>
          </form>
        <% else %>
          <button
            phx-click="start_commit"
            phx-value-folder={@project.folder}
            title="git add -A && git commit && git push"
            class="flex-1 bg-gray-800 hover:bg-gray-700 active:bg-gray-600 text-gray-300 text-xs font-medium py-1.5 rounded-lg transition-colors cursor-pointer border border-gray-700"
          >
            ↑ Commit & Push
          </button>
          <%= if @project.fly_app do %>
            <button
              phx-click="fly_deploy"
              phx-value-folder={@project.folder}
              phx-value-path={@project.fly_deploy_path}
              phx-value-name={@project.name}
              title={"fly deploy — #{@project.fly_app}"}
              class="flex-1 bg-gray-800 hover:bg-violet-900 active:bg-violet-800 text-violet-400 text-xs font-medium py-1.5 rounded-lg transition-colors cursor-pointer border border-gray-700"
            >
              🚀 fly.io
            </button>
          <% end %>
          <%= if @project.deploy_cmd do %>
            <button
              phx-click="run_deploy"
              phx-value-folder={@project.folder}
              phx-value-path={@project.path}
              phx-value-name={@project.name}
              phx-value-cmd={@project.deploy_cmd}
              title={@project.deploy_cmd}
              class="flex-1 bg-gray-800 hover:bg-emerald-900 active:bg-emerald-800 text-emerald-400 text-xs font-medium py-1.5 rounded-lg transition-colors cursor-pointer border border-gray-700"
            >
              ⚡ Deploy
            </button>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Mini card (intermediate levels) — click expands tree + scrolls to full card
  # ---------------------------------------------------------------------------

  attr :project, :map, required: true

  def mini_project_card(assigns) do
    ~H"""
    <div class="bg-gray-900 border border-gray-800 rounded-lg p-3 flex flex-col gap-2 hover:border-indigo-500 transition-colors">
      <%!-- Row 1: click = expand to full card --%>
      <button
        phx-click="expand_to_project"
        phx-value-folder={@project.folder}
        class="flex items-center justify-between gap-1 min-w-0 w-full text-left"
      >
        <span class="text-sm leading-none shrink-0">{status_emoji(@project.status_key)}</span>
        <span class="text-xs font-semibold text-gray-100 truncate flex-1 mx-1.5">{@project.name}</span>
        <span class="text-xs text-gray-500 whitespace-nowrap shrink-0">Day {@project.days_active}</span>
      </button>

      <%!-- Row 2: open button (separate) · progress bar also expands --%>
      <div class="flex items-center gap-2">
        <button
          phx-click="open_in_claude"
          phx-value-folder={@project.folder}
          phx-value-path={@project.path}
          phx-value-name={@project.name}
          title="Open in Claude"
          class="shrink-0 text-indigo-400 hover:text-indigo-300 hover:bg-indigo-900 rounded px-1 py-0.5 text-xs leading-none transition-colors"
        >▶</button>
        <button
          phx-click="expand_to_project"
          phx-value-folder={@project.folder}
          class="flex-1 flex items-center gap-2 min-w-0"
        >
          <div class="flex-1 bg-gray-800 rounded-full h-1.5">
            <div
              class={["h-1.5 rounded-full", progress_color(@project.progress)]}
              style={"width: #{@project.progress}%"}
            />
          </div>
          <span class="text-xs text-gray-500 font-mono w-8 text-right shrink-0">{@project.progress}%</span>
        </button>
      </div>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Shared helpers
  # ---------------------------------------------------------------------------

  def status_emoji(:active),   do: "🟢"
  def status_emoji(:planning), do: "🟡"
  def status_emoji(:paused),   do: "🔴"
  def status_emoji(:live),     do: "✅"
  def status_emoji(_),         do: "⚪"

  defp status_color(:active),   do: "bg-green-900 text-green-300"
  defp status_color(:planning), do: "bg-yellow-900 text-yellow-300"
  defp status_color(:paused),   do: "bg-red-900 text-red-300"
  defp status_color(:live),     do: "bg-blue-900 text-blue-300"
  defp status_color(_),         do: "bg-gray-800 text-gray-300"

  defp status_label(status) do
    case String.split(status, " ", parts: 2) do
      [_emoji, rest] -> rest
      [only]         -> only
    end
  end

  def progress_color(p) when p >= 75, do: "bg-green-500"
  def progress_color(p) when p >= 40, do: "bg-yellow-500"
  def progress_color(_),               do: "bg-gray-600"

  defp indent(0), do: ""
  defp indent(1), do: "  · "
  defp indent(2), do: "    · "
  defp indent(n), do: String.duplicate("  ", n) <> "· "

  defp format_date(nil),  do: "unknown"
  defp format_date(date), do: Calendar.strftime(date, "%b %d")
end
