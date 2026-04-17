defmodule Hub.DailySync do
  @doc """
  Finds all projects with STATUS.md modified today (or in the pinned list), then
  git add -A / commit / push each. Pinned projects that have no git repo will have
  one initialized locally and on GitHub before committing.
  Returns a list of result maps.
  """

  # GITHUB_TOKEN (set by Claude Code) is read-only and blocks pushes — unset it for all git ops.
  @git_env [{"GITHUB_TOKEN", nil}]

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

    case git(["rev-parse", "--git-dir"], git_path) do
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
    git(["init"], git_path)
    git(["branch", "-M", "main"], git_path)

    case git(["remote", "get-url", "origin"], git_path) do
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

    git(["add", "-A"], git_path)

    commit_status =
      case git(["commit", "-F", msg_file], git_path) do
        {_, 0} -> :committed
        {output, _} ->
          if String.contains?(output, "nothing to commit"), do: :clean, else: :commit_error
      end

    pushed =
      if commit_status in [:committed, :clean] do
        try_push(git_path)
      else
        nil
      end

    %{name: project.name, status: commit_status, pushed: pushed}
  end

  defp try_push(git_path) do
    case git(["remote", "get-url", "origin"], git_path) do
      {_, 0} ->
        case git(["push", "-u", "origin", "HEAD"], git_path) do
          {_, 0} -> :ok
          {error, _} ->
            if String.contains?(error, "repository not found") or String.contains?(error, "does not exist") do
              folder = Path.basename(git_path)
              System.cmd("gh", ["repo", "create", folder, "--private", "--source=.", "--remote=origin"],
                cd: git_path, stderr_to_stdout: true)
              case git(["push", "-u", "origin", "HEAD"], git_path) do
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

  defp git(args, path) do
    System.cmd("git", args, cd: path, stderr_to_stdout: true, env: @git_env)
  end
end
