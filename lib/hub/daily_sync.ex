defmodule Hub.DailySync do
  @doc """
  Finds all projects with STATUS.md modified today, then git add -A / commit / push each.
  Returns a list of result maps.
  """
  def sync_today do
    Hub.ProjectScanner.scan()
    |> Enum.filter(& &1.git_dirty)
    |> Enum.map(&sync_project/1)
  end

  defp sync_project(project) do
    git_path = project.git_path || project.path

    case System.cmd("git", ["rev-parse", "--git-dir"], cd: git_path, stderr_to_stdout: true) do
      {_, 0} -> do_commit_and_push(project, git_path)
      _ -> %{name: project.name, status: :no_git, pushed: nil}
    end
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
      if commit_status in [:committed, :clean] do
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
          {error, _} -> {:error, String.trim(error)}
        end

      _ ->
        :no_remote
    end
  end
end
