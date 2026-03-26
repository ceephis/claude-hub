defmodule Hub.ProjectWatcher do
  use GenServer
  require Logger

  @topic "projects:updated"

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def topic, do: @topic

  @impl true
  def init(_opts) do
    {:ok, watcher_pid} =
      FileSystem.start_link(dirs: [Hub.ProjectScanner.claude_dir()])

    FileSystem.subscribe(watcher_pid)
    {:ok, %{watcher_pid: watcher_pid}}
  end

  @impl true
  def handle_info({:file_event, _pid, {path, _events}}, state) do
    if relevant?(path) do
      Logger.debug("Hub: file change detected — #{path}")
      Phoenix.PubSub.broadcast(Hub.PubSub, @topic, :projects_updated)
    end

    {:noreply, state}
  end

  def handle_info({:file_event, _pid, :stop}, state) do
    {:noreply, state}
  end

  # Only care about STATUS.md/timesheet.md changes or new/removed directories
  defp relevant?(path) do
    String.ends_with?(path, "STATUS.md") or
      String.ends_with?(path, "timesheet.md") or
      File.dir?(path)
  end
end
