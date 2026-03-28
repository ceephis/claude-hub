defmodule Hub.TimesheetFixer do
  @timesheet_path Path.expand("~/Desktop/Claude/timesheet/timesheet.md")

  @doc """
  Reads timesheet.md, recalculates Week Total and Project Breakdown for every
  week section from raw data rows, and writes the file back if anything changed.
  Returns :updated or :unchanged.
  """
  def fix do
    case File.read(@timesheet_path) do
      {:ok, content} ->
        fixed = recalculate(content)
        if fixed != content do
          File.write!(@timesheet_path, fixed)
          :updated
        else
          :unchanged
        end
      {:error, _} ->
        :error
    end
  end

  # ---------------------------------------------------------------------------
  # Line-by-line state machine
  # state: :normal | :in_week | :in_breakdown
  # ---------------------------------------------------------------------------

  defp recalculate(content) do
    lines = String.split(content, "\n")
    {out, _week_rows, _mode} = Enum.reduce(lines, {[], [], :normal}, &step/2)
    out |> Enum.reverse() |> Enum.join("\n")
  end

  defp step(line, {out, week_rows, mode}) do
    cond do
      # Start of a new week section — reset row collection
      String.starts_with?(line, "## Week of") ->
        {[line | out], [], :in_week}

      # Data row — collect it
      mode == :in_week && data_row?(line) ->
        row = parse_row(line)
        {[line | out], [row | week_rows], :in_week}

      # Week Total row in main table — replace with correct sum
      mode == :in_week && week_total_row?(line) ->
        total = sum_hours(week_rows)
        {[week_total_line(total) | out], week_rows, :in_week}

      # Project Breakdown header — emit new table, switch to skip mode
      mode == :in_week && line == "### Project Breakdown" ->
        total = sum_hours(week_rows)
        breakdown = build_breakdown(week_rows, total)
        new_out = Enum.reduce([line | breakdown], out, fn l, acc -> [l | acc] end)
        {new_out, week_rows, :in_breakdown}

      # Inside old breakdown table — skip these rows
      mode == :in_breakdown && String.starts_with?(line, "|") ->
        {out, week_rows, :in_breakdown}

      # First non-table line after breakdown — resume in_week
      mode == :in_breakdown ->
        {[line | out], week_rows, :in_week}

      true ->
        {[line | out], week_rows, mode}
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp data_row?(line),
    do: Regex.match?(~r/^\|\s*\d{4}-\d{2}-\d{2}\s*\|/, line)

  defp week_total_row?(line),
    do: String.contains?(line, "**Week Total**") && String.contains?(line, "|")

  defp parse_row(line) do
    case Regex.run(~r/^\|\s*\d{4}-\d{2}-\d{2}\s*\|[^|]+\|([^|]+)\|\s*([\d.]+)\s*\|/, line) do
      [_, project, hours] ->
        {h, _} = Float.parse(String.trim(hours))
        %{project: String.trim(project), hours: h}
      _ ->
        %{project: "Unknown", hours: 0.0}
    end
  end

  defp sum_hours(rows), do: rows |> Enum.map(& &1.hours) |> Enum.sum()

  defp week_total_line(total), do: "| **Week Total** | | | **#{fmt(total)}** | |"

  # Build project breakdown in first-appearance order
  defp build_breakdown(rows, total) do
    by_project =
      rows
      |> Enum.reverse()
      |> Enum.reduce([], fn %{project: p, hours: h}, acc ->
        case Enum.find_index(acc, fn {proj, _} -> proj == p end) do
          nil -> acc ++ [{p, h}]
          idx -> List.update_at(acc, idx, fn {proj, hrs} -> {proj, hrs + h} end)
        end
      end)

    project_rows = Enum.map(by_project, fn {proj, hrs} -> "| #{proj} | #{fmt(hrs)} |" end)

    ["| Project | Hours |", "|---|---|"] ++
      project_rows ++
      ["| **Week Total** | **#{fmt(total)}** |"]
  end

  defp fmt(h) do
    rounded = Float.round(h, 2)
    str = :erlang.float_to_binary(rounded, [{:decimals, 2}, :compact])
    if String.contains?(str, "."), do: str, else: str <> ".0"
  end
end
