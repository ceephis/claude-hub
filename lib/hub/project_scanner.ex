defmodule Hub.ProjectScanner do
  @claude_dir Path.expand("~/Desktop/Claude")
  @excluded ["portfolio", "timesheet", ".claude"]

  @doc """
  Scans ~/Desktop/Claude/ and returns a list of parsed project maps
  for every folder that contains a STATUS.md.
  """
  def scan do
    @claude_dir
    |> File.ls!()
    |> Enum.reject(&(&1 in @excluded))
    |> Enum.reject(&String.starts_with?(&1, "."))
    |> Enum.map(&build_project(@claude_dir, &1))
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(& &1.name)
  end

  def claude_dir, do: @claude_dir

  defp build_project(base, folder) do
    status_path = Path.join([base, folder, "STATUS.md"])
    project_path = Path.join(base, folder)

    case Hub.StatusParser.parse(status_path) do
      nil -> nil
      parsed ->
        {fly_app, fly_deploy_path} = detect_fly(project_path)
        git_path = find_git_path(project_path)
        Map.merge(parsed, %{
          folder:         folder,
          path:           project_path,
          git_path:       git_path,
          fly_app:        fly_app,
          fly_deploy_path: fly_deploy_path,
          modified_today: status_modified_today?(status_path),
          git_dirty:      git_dirty?(git_path || project_path)
        })
    end
  end

  defp status_modified_today?(status_path) do
    today = Date.utc_today()

    case File.stat(status_path) do
      {:ok, %{mtime: mtime}} ->
        {local_date, _} = :calendar.universal_time_to_local_time(mtime)
        Date.from_erl!(local_date) == today

      _ ->
        false
    end
  end

  defp git_dirty?(git_path) do
    case System.cmd("git", ["status", "--porcelain"], cd: git_path, stderr_to_stdout: true) do
      {output, 0} -> String.trim(output) != ""
      _ -> false
    end
  end

  defp find_git_path(project_path) do
    if File.exists?(Path.join(project_path, ".git")) do
      project_path
    else
      case File.ls(project_path) do
        {:ok, entries} ->
          entries
          |> Enum.find(fn entry ->
            subdir = Path.join(project_path, entry)
            File.dir?(subdir) && File.exists?(Path.join(subdir, ".git"))
          end)
          |> case do
            nil -> project_path
            subdir -> Path.join(project_path, subdir)
          end
        _ -> project_path
      end
    end
  end

  defp detect_fly(project_path) do
    toml =
      Path.wildcard(Path.join(project_path, "fly.toml")) ++
      Path.wildcard(Path.join(project_path, "*/fly.toml"))
      |> List.first()

    case toml do
      nil -> {nil, nil}
      path ->
        app_name =
          case File.read(path) do
            {:ok, content} ->
              case Regex.run(~r/^app\s*=\s*["']([^"']+)["']/m, content) do
                [_, name] -> name
                _ -> nil
              end
            _ -> nil
          end
        {app_name, Path.dirname(path)}
    end
  end
end
