defmodule Hub.TimesheetParser do
  @timesheet_path Path.expand("~/Desktop/Claude/timesheet/timesheet.md")

  @doc """
  Returns %{total_hours: float, week_hours: float} parsed from timesheet.md.
  Weeks are listed most-recent-first, so the first Week Total is this week.
  """
  def parse do
    case File.read(@timesheet_path) do
      {:ok, content} -> parse_content(content)
      {:error, _}    -> %{total_hours: 0.0, week_hours: 0.0}
    end
  end

  defp parse_content(content) do
    totals =
      content
      |> String.split("\n")
      |> Enum.filter(&String.contains?(&1, "**Week Total**"))
      |> Enum.map(&extract_hours/1)
      |> Enum.reject(&is_nil/1)

    week_hours  = List.first(totals) || 0.0
    total_hours = Enum.sum(totals)

    %{total_hours: total_hours, week_hours: week_hours}
  end

  # Matches: | **Week Total** | | | **22.75** | |
  defp extract_hours(line) do
    case Regex.run(~r/\|\s*\*\*[\d.]+\*\*\s*\|/, line) do
      [match] ->
        match
        |> String.replace(~r/[^\d.]/, "")
        |> Float.parse()
        |> case do
          {hours, _} -> hours
          :error     -> nil
        end
      _ -> nil
    end
  end
end
