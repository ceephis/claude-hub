defmodule Hub.StatusParser do
  @doc """
  Parses a STATUS.md file and returns a map of project metadata.

  Returns:
    %{
      name:        "EMDR Therapy Session Manager",
      status:      "🟢 Active",
      status_key:  :active,
      started:     ~D[2026-03-23],
      days_active: 3,
      stack:       "Elixir/Phoenix · LiveView · ...",
      next_action: "Legal pages (ToS, Privacy Policy, ...)",
      live_url:    "switch2emdr.com",   # nil if absent
      tasks_done:  39,
      tasks_total: 48,
      progress:    81
    }
  """
  def parse(path) do
    case File.read(path) do
      {:ok, content} -> parse_content(content)
      {:error, _} -> nil
    end
  end

  defp parse_content(content) do
    lines = String.split(content, "\n")

    %{
      name:        parse_name(lines),
      status:      parse_field(lines, "Status"),
      status_key:  parse_status_key(lines),
      started:     parse_started(lines),
      days_active: parse_days_active(lines),
      stack:       parse_field(lines, "Stack"),
      next_action: parse_next_action(lines),
      live_url:    parse_field(lines, "Domain"),
      deploy_cmd:  parse_field(lines, "Deploy"),
      tasks_done:  count_tasks(lines, :done),
      tasks_total: count_tasks(lines, :total),
      progress:    calc_progress(lines)
    }
  end

  defp parse_name(lines) do
    lines
    |> Enum.find(&String.starts_with?(&1, "# "))
    |> case do
      nil -> "Unknown"
      line -> String.replace_prefix(line, "# ", "") |> String.trim()
    end
  end

  defp parse_field(lines, field) do
    lines
    |> Enum.find(&String.match?(&1, ~r/^\*\*#{field}:\*\*/))
    |> case do
      nil -> nil
      line ->
        line
        |> String.replace(~r/^\*\*#{field}:\*\*\s*/, "")
        |> String.trim()
    end
  end

  defp parse_status_key(lines) do
    case parse_field(lines, "Status") do
      nil -> :unknown
      status ->
        cond do
          String.contains?(status, "🟢") -> :active
          String.contains?(status, "🟡") -> :planning
          String.contains?(status, "🔴") or String.contains?(status, "⏸️") -> :paused
          String.contains?(status, "✅") -> :live
          String.contains?(status, "🔵") -> :active
          String.contains?(status, "🧪") -> :beta
          true -> :unknown
        end
    end
  end

  defp parse_started(lines) do
    case parse_field(lines, "Started") do
      nil -> nil
      date_str ->
        case Date.from_iso8601(date_str) do
          {:ok, date} -> date
          _ -> nil
        end
    end
  end

  defp parse_days_active(lines) do
    case parse_started(lines) do
      nil -> nil
      started -> Date.diff(Date.utc_today(), started)
    end
  end

  defp parse_next_action(lines) do
    idx = Enum.find_index(lines, &String.match?(&1, ~r/^## Next Action/i))

    case idx do
      nil -> nil
      i ->
        lines
        |> Enum.drop(i + 1)
        |> Enum.reject(&(String.trim(&1) == ""))
        |> List.first()
        |> case do
          nil -> nil
          line -> String.trim(line)
        end
    end
  end

  defp count_tasks(lines, :done) do
    Enum.count(lines, &String.match?(&1, ~r/^\s*- \[x\]/i))
  end

  defp count_tasks(lines, :total) do
    Enum.count(lines, &String.match?(&1, ~r/^\s*- \[[x ]\]/i))
  end

  defp calc_progress(lines) do
    done  = count_tasks(lines, :done)
    total = count_tasks(lines, :total)

    if total > 0, do: round(done / total * 100), else: 0
  end
end
