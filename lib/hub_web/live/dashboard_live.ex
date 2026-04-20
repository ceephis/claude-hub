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
     |> assign(:sync_status, load_sync_status())
     |> assign(:pinned_for_sync, Hub.SyncPins.load())}
  end

  @impl true
  def handle_info(:projects_updated, socket) do
    {:noreply, assign(socket, load_data())}
  end

  @impl true
  def handle_info({:sync_done, results}, socket) do
    Hub.SyncPins.save_report(results)
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
  def handle_event("move_group", %{"id" => id, "dir" => dir}, socket) do
    groups  = Hub.Groups.load()
    updated = Hub.Groups.move_group(groups, id, String.to_existing_atom(dir))
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
          write text "printf '\\\\033]1337;SetBadgeFormat=#{badge_b64}\\\\007' && cd #{path} && claude --continue"
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
  def handle_event("toggle_sync_pin", %{"folder" => folder}, socket) do
    updated = Hub.SyncPins.toggle(socket.assigns.pinned_for_sync, folder)
    {:noreply, assign(socket, :pinned_for_sync, updated)}
  end

  def handle_event("sync_today", _params, socket) do
    pid = self()
    pinned = MapSet.to_list(socket.assigns.pinned_for_sync)

    Task.start(fn ->
      results = Hub.DailySync.sync_today(pinned)
      send(pid, {:sync_done, results})
    end)

    {:noreply, assign(socket, :sync_status, :running)}
  end

  @impl true
  def handle_event("dismiss_sync", _params, socket) do
    Hub.SyncPins.clear_report()
    {:noreply, assign(socket, :sync_status, nil)}
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
  # VPS deploy
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("vps_deploy", %{"folder" => folder, "app" => app, "name" => name}, socket) do
    cmd = "ssh deploy@2.24.198.100 '/home/deploy/deploy.sh #{app}'"
    run_in_iterm("/tmp", cmd, folder, name)
    {:noreply, socket}
  end

  # ---------------------------------------------------------------------------
  # VPS provision — new app, step 1: prompt for domain via JS hook
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("vps_provision", %{"folder" => folder, "name" => name, "app" => app, "repo" => repo}, socket) do
    {:noreply, push_event(socket, "prompt_provision", %{folder: folder, name: name, app: app, repo: repo})}
  end

  # ---------------------------------------------------------------------------
  # VPS provision — step 2: domain entered, auto-assign port and run provision.sh
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("domain_entered", %{"folder" => folder, "domain" => domain, "repo" => repo, "app" => app}, socket) do
    registry_path = Path.expand("~/Desktop/Claude/vps/port_registry.txt")

    next_port =
      case File.read(registry_path) do
        {:ok, contents} ->
          case Regex.run(~r/^#{app}:(\d+)$/m, contents) do
            [_, port] ->
              String.to_integer(port)
            nil ->
              # App not in registry — take max port + 100
              ports = Regex.scan(~r/:(\d+)/, contents) |> Enum.map(fn [_, p] -> String.to_integer(p) end)
              (Enum.max(ports, fn -> 4000 end)) + 100
          end
        _ -> 4100
      end

    script = Path.expand("~/Desktop/Claude/vps/dev/scripts/provision.sh")
    cmd = "source ~/.zshrc && #{script} #{app} #{next_port} #{domain} #{repo} '#{folder}'"
    run_in_iterm("/tmp", cmd, folder, "Provision #{app}")
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

  defp load_sync_status do
    case Hub.SyncPins.load_report() do
      nil     -> nil
      results -> {:done, results}
    end
  end
end
