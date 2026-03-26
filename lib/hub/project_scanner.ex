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

    case Hub.StatusParser.parse(status_path) do
      nil -> nil
      parsed -> Map.merge(parsed, %{folder: folder, path: Path.join(base, folder)})
    end
  end
end
