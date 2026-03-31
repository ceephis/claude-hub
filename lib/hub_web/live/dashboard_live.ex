defmodule HubWeb.DashboardLive do
  use HubWeb, :live_view
  import HubWeb.GroupAccordion

  @five_minutes 5 * 60 * 1000

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Hub.PubSub, Hub.ProjectWatcher.topic())
      Process.send_after(self(), :auto_fix_timesheet, @five_minutes)
    end

    {:ok,
     socket
     |> assign(load_data())
     |> assign(:filters, [])
     |> assign(:search, "")
     |> assign(:expanded, MapSet.new())
     |> assign(:editing_group, nil)
     |> assign(:adding_to, nil)
     |> assign(:committing, nil)
     |> assign(:sync_status, nil)}
  end

  @impl true
  def handle_info(:projects_updated, socket) do
    {:noreply, assign(socket, load_data())}
  end

  @impl true
  def handle_info({:sync_done, results}, socket) do
    {:noreply, assign(socket, :sync_status, {:done, results})}
  end

  @impl true
  def handle_info(:auto_fix_timesheet, socket) do
    Hub.TimesheetFixer.fix()
    Process.send_after(self(), :auto_fix_timesheet, @five_minutes)
    {:noreply, assign(socket, load_data())}
  end

  @impl true
  def handle_event("fix_timesheet", _, socket) do
    Hub.TimesheetFixer.fix()
    {:noreply, assign(socket, load_data())}
  end

  # ---------------------------------------------------------------------------
  # Expand / collapse
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("toggle_group", %{"id" => id}, socket) do
    expanded =
      if MapSet.member?(socket.assigns.expanded, id),
        do:   MapSet.delete(socket.assigns.expanded, id),
        else: MapSet.put(socket.assigns.expanded, id)

    {:noreply, assign(socket, :expanded, expanded)}
  end

  # ---------------------------------------------------------------------------
  # Filters
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("toggle_filter", %{"status" => status}, socket) do
    key     = String.to_existing_atom(status)
    current = socket.assigns.filters

    filters =
      if key in current, do: List.delete(current, key), else: [key | current]

    {:noreply, assign(socket, :filters, filters)}
  end

  @impl true
  def handle_event("clear_filters", _params, socket) do
    {:noreply, assign(socket, :filters, [])}
  end

  @impl true
  def handle_event("search", %{"q" => q}, socket) do
    {:noreply, assign(socket, :search, String.trim(q))}
  end

  # ---------------------------------------------------------------------------
  # Group management
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("start_add_group", %{"parent_id" => parent_id}, socket) do
    {:noreply,
     socket
     |> assign(:adding_to, parent_id)
     |> assign(:editing_group, nil)
     |> ensure_expanded(parent_id)}
  end

  @impl true
  def handle_event("create_group", %{"parent_id" => parent_id, "name" => name}, socket) do
    name = String.trim(name)

    if name == "" do
      {:noreply, assign(socket, :adding_to, nil)}
    else
      groups = Hub.Groups.load()
      updated = Hub.Groups.create_group(groups, parent_id, name)
      Hub.Groups.save(updated)

      {:noreply,
       socket
       |> assign(:adding_to, nil)
       |> assign(load_data())}
    end
  end

  @impl true
  def handle_event("start_edit_group", %{"id" => id}, socket) do
    {:noreply,
     socket
     |> assign(:editing_group, id)
     |> assign(:adding_to, nil)}
  end

  @impl true
  def handle_event("rename_group", %{"group_id" => id, "name" => name}, socket) do
    name = String.trim(name)

    if name == "" do
      {:noreply, assign(socket, :editing_group, nil)}
    else
      groups  = Hub.Groups.load()
      updated = Hub.Groups.rename_group(groups, id, name)
      Hub.Groups.save(updated)

      {:noreply,
       socket
       |> assign(:editing_group, nil)
       |> assign(load_data())}
    end
  end

  @impl true
  def handle_event("delete_group", %{"id" => id}, socket) do
    groups  = Hub.Groups.load()
    updated = Hub.Groups.delete_group(groups, id)
    Hub.Groups.save(updated)

    {:noreply, assign(socket, load_data())}
  end

  @impl true
  def handle_event("cancel_edit", _params, socket) do
    {:noreply,
     socket
     |> assign(:editing_group, nil)
     |> assign(:adding_to, nil)}
  end

  # ---------------------------------------------------------------------------
  # Mini card click — expand tree to project + scroll to full card
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("expand_to_project", %{"folder" => folder}, socket) do
    groups = Hub.Groups.load()
    path   = Hub.Groups.path_to_project(groups, folder) || []

    expanded =
      Enum.reduce(path, socket.assigns.expanded, &MapSet.put(&2, &1))

    {:noreply,
     socket
     |> assign(:expanded, expanded)
     |> push_event("scroll_to", %{id: "card-#{folder}"})}
  end

  # ---------------------------------------------------------------------------
  # Move card
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("move_card", %{"folder" => _folder, "to_group_id" => ""}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("move_card", %{"folder" => folder, "to_group_id" => to_id}, socket) do
    groups  = Hub.Groups.load()
    updated = Hub.Groups.move_project(groups, folder, to_id)
    Hub.Groups.save(updated)

    {:noreply, assign(socket, load_data())}
  end

  # ---------------------------------------------------------------------------
  # Open in Claude
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("open_in_claude", %{"folder" => folder, "path" => path, "name" => name}, socket) do
    # AppleScript files are parsed as MacRoman — multi-byte UTF-8 chars (e.g. em dash)
    # cause byte 0x94 to be read as a curly quote, terminating the string early.
    # Use the badge (base64-encoded, safe) for the full name; ASCII-only for set name.
    safe_name = name
      |> String.replace("—", "-")
      |> String.replace("–", "-")
      |> String.replace(~r/[^\x00-\x7F]/, "")
      |> String.replace(~r/"/, "'")

    badge_b64 = Base.encode64(name)

    script = """
    tell application "iTerm"
      activate
      if (count of windows) = 0 then
        create window with default profile
      end if
      tell current window
        create tab with default profile
        tell current session
          set name to "#{safe_name}"
          write text "printf '\\\\033]1337;SetBadgeFormat=#{badge_b64}\\\\007' && cd #{path} && claude"
        end tell
      end tell
    end tell
    """

    script_path = "/tmp/hub_open_#{folder}.applescript"
    File.write!(script_path, script)

    Task.start(fn ->
      case System.cmd("osascript", [script_path], stderr_to_stdout: true) do
        {_output, 0} ->
          :ok
        {error, code} ->
          require Logger
          Logger.error("open_in_claude: osascript failed (#{code}): #{error}")
      end
    end)

    {:noreply, socket}
  end

# ---------------------------------------------------------------------------
  # Daily sync
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("sync_today", _params, socket) do
    pid = self()

    Task.start(fn ->
      results = Hub.DailySync.sync_today()
      send(pid, {:sync_done, results})
    end)

    {:noreply, assign(socket, :sync_status, :running)}
  end

  @impl true
  def handle_event("dismiss_sync", _params, socket) do
    {:noreply, assign(socket, :sync_status, nil)}
  end

  # ---------------------------------------------------------------------------
  # Commit & Push
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("start_commit", %{"folder" => folder}, socket) do
    {:noreply, assign(socket, :committing, folder)}
  end

  @impl true
  def handle_event("cancel_commit", _params, socket) do
    {:noreply, assign(socket, :committing, nil)}
  end

  @impl true
  def handle_event("commit_and_push", %{"folder" => folder, "path" => path, "name" => name, "message" => msg}, socket) do
    msg = String.trim(msg)
    if msg != "" do
      msg_file = "/tmp/hub_commit_#{folder}.txt"
      File.write!(msg_file, msg)
      cmd = """
      (git rev-parse --git-dir > /dev/null 2>&1 || (git init && git branch -M main)) && \
      (git remote get-url origin > /dev/null 2>&1 || gh repo create #{folder} --private --source=. --remote=origin) && \
      git add -A && git commit -F #{msg_file} && git push -u origin HEAD\
      """
      run_in_iterm(path, cmd, folder, name)
    end
    {:noreply, assign(socket, :committing, nil)}
  end

  # ---------------------------------------------------------------------------
  # fly.io deploy
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("fly_deploy", %{"folder" => folder, "path" => path, "name" => name}, socket) do
    run_in_iterm(path, "fly deploy", folder, name)
    {:noreply, socket}
  end

  # ---------------------------------------------------------------------------
  # Deploy button — custom deploy cmd
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("run_deploy", %{"folder" => folder, "path" => path, "name" => name, "cmd" => cmd}, socket) do
    run_in_iterm(path, cmd, folder, name)
    {:noreply, socket}
  end

  defp run_in_iterm(path, cmd, folder, name) do
    safe_name = name
      |> String.replace("—", "-")
      |> String.replace("–", "-")
      |> String.replace(~r/[^\x00-\x7F]/, "")
      |> String.replace(~r/"/, "'")

    badge_b64 = Base.encode64(name)

    script = """
    tell application "iTerm"
      activate
      if (count of windows) = 0 then
        create window with default profile
      end if
      tell current window
        create tab with default profile
        tell current session
          set name to "#{safe_name}"
          write text "printf '\\\\033]1337;SetBadgeFormat=#{badge_b64}\\\\007' && cd #{path} && #{cmd}"
        end tell
      end tell
    end tell
    """

    script_path = "/tmp/hub_deploy_#{folder}.applescript"
    File.write!(script_path, script)

    Task.start(fn ->
      case System.cmd("osascript", [script_path], stderr_to_stdout: true) do
        {_output, 0} -> :ok
        {error, code} ->
          require Logger
          Logger.error("run_in_iterm: osascript failed (#{code}): #{error}")
      end
    end)
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  def filter_active_class(:active),    do: "bg-green-700 text-white"
  def filter_active_class(:planning),  do: "bg-yellow-700 text-white"
  def filter_active_class(:paused),    do: "bg-red-700 text-white"
  def filter_active_class(:live),      do: "bg-blue-700 text-white"
  def filter_active_class(:today),     do: "bg-purple-700 text-white"
  def filter_active_class(:needs_git), do: "bg-orange-700 text-white"
  def filter_active_class(_),          do: "bg-indigo-600 text-white"

  defp ensure_expanded(socket, "root"), do: socket
  defp ensure_expanded(socket, id) do
    assign(socket, :expanded, MapSet.put(socket.assigns.expanded, id))
  end

  defp format_hours(h) when is_float(h) do
    int  = trunc(h)
    mins = round((h - int) * 60)
    if mins == 0, do: "#{int}h", else: "#{int}h #{mins}m"
  end

  defp format_hours(h), do: "#{h}h"

  defp load_data do
    projects  = Hub.ProjectScanner.scan()
    groups    = Hub.Groups.load()
    timesheet = Hub.TimesheetParser.parse()
    {grouped, uncategorized} = Hub.Groups.assign_projects(groups, projects)

    %{
      grouped:        grouped,
      uncategorized:  uncategorized,
      total_projects: length(projects),
      group_options:  Hub.Groups.flat_list(groups),
      today_hours:    format_hours(timesheet.today_hours),
      week_hours:     format_hours(timesheet.week_hours),
      total_hours:    format_hours(timesheet.total_hours)
    }
  end
end
