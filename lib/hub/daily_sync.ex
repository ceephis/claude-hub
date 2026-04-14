defmodule Hub.DailySync do
  @doc """
  Finds all projects with STATUS.md modified today (or in the pinned list), then
  git add -A / commit / push each. Pinned projects that have no git repo will have
  one initialized locally and on GitHub before committing.
  Returns a list of result maps.
  """
  def sync_today(pinned_folders \\ []) do
    all_projects = Hub.ProjectScanner.scan()

    to_sync =
      all_projects
      |> Enum.filter(fn p -> p.git_dirty or p.folder in pinned_folders end)
      |> Enum.uniq_by(& &1.folder)

    Enum.map(to_sync, fn p ->
      sync_project(p, p.folder in pinned_folders)
    end)
  end

  defp sync_project(project, force_init) do
    git_path = project.git_path || project.path

    case System.cmd("git", ["rev-parse", "--git-dir"], cd: git_path, stderr_to_stdout: true) do
      {_, 0} -> do_commit_and_push(project, git_path)
      _ ->
        if force_init do
          do_init_and_push(project, git_path)
        else
          %{name: project.name, status: :no_git, pushed: nil}
        end
    end
  end

  defp do_init_and_push(project, git_path) do
    System.cmd("git", ["init"], cd: git_path, stderr_to_stdout: true)
    System.cmd("git", ["branch", "-M", "main"], cd: git_path, stderr_to_stdout: true)

    case System.cmd("git", ["remote", "get-url", "origin"], cd: git_path, stderr_to_stdout: true) do
      {_, 0} -> :ok
      _ ->
        System.cmd("gh", ["repo", "create", project.folder, "--private", "--source=.", "--remote=origin"],
          cd: git_path, stderr_to_stdout: true)
    end

    do_commit_and_push(project, git_path)
  end

  defp do_commit_and_push(project, git_path) do
    date_str = Date.to_iso8601(Date.utc_today())
    msg_file = "/tmp/hub_sync_#{project.folder}.txt"
    File.write!(msg_file, "Daily sync #{date_str}")

    System.cmd("git", ["add", "-A"], cd: git_path, stderr_to_stdout: true)

    commit_status =
      case System.cmd("git", ["commit", "-F", msg_file], cd: git_path, stderr_to_stdout: true) do
        {_, 0} -> :committed
        {output, _} ->
          if String.contains?(output, "nothing to commit"), do: :clean, else: :commit_error
      end

    pushed =
      if commit_status == :committed do
        try_push(git_path)
      else
        nil
      end

    %{name: project.name, status: commit_status, pushed: pushed}
  end

  defp try_push(git_path) do
    case System.cmd("git", ["remote", "get-url", "origin"], cd: git_path, stderr_to_stdout: true) do
      {_, 0} ->
        case System.cmd("git", ["push", "-u", "origin", "HEAD"], cd: git_path, stderr_to_stdout: true) do
          {_, 0} -> :ok
          {error, _} ->
            if String.contains?(error, "repository not found") or String.contains?(error, "does not exist") do
              folder = Path.basename(git_path)
              System.cmd("gh", ["repo", "create", folder, "--private", "--source=.", "--remote=origin"],
                cd: git_path, stderr_to_stdout: true)
              case System.cmd("git", ["push", "-u", "origin", "HEAD"], cd: git_path, stderr_to_stdout: true) do
                {_, 0} -> :ok
                {error2, _} -> {:error, String.trim(error2)}
              end
            else
              {:error, String.trim(error)}
            end
        end

      _ ->
        :no_remote
    end
  end
end
