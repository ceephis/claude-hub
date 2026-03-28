defmodule Hub.TimesheetParser do
  @timesheet_path Path.expand("~/Desktop/Claude/timesheet/timesheet.md")

  @doc """
  Returns %{total_hours: float, week_hours: float, today_hours: float} parsed from timesheet.md.
  All totals are computed from raw data rows — never from Claude-written total lines.
  """
  def parse do
    case File.read(@timesheet_path) do
      {:ok, content} -> parse_content(content)
      {:error, _}    -> %{total_hours: 0.0, week_hours: 0.0, today_hours: 0.0}
    end
  end

  defp parse_content(content) do
    today = today_eastern()
    current_week_start = current_week_start(today)

    data_rows =
      content
      |> String.split("\n")
      |> Enum.map(&parse_row/1)
      |> Enum.reject(&is_nil/1)

    today_hours =
      data_rows
      |> Enum.filter(fn {date, _hours} -> date == today end)
      |> Enum.map(fn {_date, hours} -> hours end)
      |> Enum.sum()

    week_hours =
      data_rows
      |> Enum.filter(fn {date, _hours} -> date >= current_week_start end)
      |> Enum.map(fn {_date, hours} -> hours end)
      |> Enum.sum()

    total_hours =
      data_rows
      |> Enum.map(fn {_date, hours} -> hours end)
      |> Enum.sum()

    %{total_hours: total_hours, week_hours: week_hours, today_hours: today_hours}
  end

  # Parses a data row: | 2026-03-26 | Thursday | Project | 1.5 | desc |
  # Returns {date_string, hours} or nil
  defp parse_row(line) do
    case Regex.run(~r/^\|\s*(\d{4}-\d{2}-\d{2})\s*\|[^|]+\|[^|]+\|\s*([\d.]+)\s*\|/, line) do
      [_, date, hours] ->
        case Float.parse(hours) do
          {h, _} -> {date, h}
          :error -> nil
        end
      _ -> nil
    end
  end

  defp today_eastern do
    {date_str, 0} = System.cmd("date", ["+%Y-%m-%d"])
    String.trim(date_str)
  end

  # Week starts on Monday — find the most recent Monday on or before today
  defp current_week_start(today) do
    {:ok, date} = Date.from_iso8601(today)
    days_since_monday = Date.day_of_week(date) - 1
    date |> Date.add(-days_since_monday) |> Date.to_iso8601()
  end
end
