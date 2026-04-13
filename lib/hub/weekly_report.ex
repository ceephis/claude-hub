defmodule Hub.WeeklyReport do
  @timesheet_path Path.expand("~/Desktop/Claude/timesheet/timesheet.md")

  @doc """
  Builds the full weekly report data for a given week_start (Monday).
  """
  def build(week_start) do
    week_end = Date.add(week_start, 6)

    %{
      week_start: week_start,
      week_end: week_end,
      timesheet: build_timesheet(week_start, week_end),
      projects_progress: build_projects_progress(week_start, week_end),
      changed_projects: build_changed_projects(week_start, week_end)
    }
  end

  @doc "Returns the Monday of the previous week."
  def previous_week_start do
    today = Date.utc_today()
    days_since_monday = Date.day_of_week(today) - 1
    today |> Date.add(-days_since_monday) |> Date.add(-7)
  end

  @doc "Parses week param, falling back to previous week."
  def week_start_from_param(nil), do: previous_week_start()

  def week_start_from_param(date_str) do
    case Date.from_iso8601(date_str) do
      {:ok, date} -> date
      _ -> previous_week_start()
    end
  end

  @doc "Returns {prev_week_monday, next_week_monday} for navigation."
  def adjacent_weeks(week_start) do
    {Date.add(week_start, -7), Date.add(week_start, 7)}
  end

  # ---------------------------------------------------------------------------
  # Timesheet
  # ---------------------------------------------------------------------------

  defp build_timesheet(week_start, week_end) do
    start_str = Date.to_iso8601(week_start)
    end_str   = Date.to_iso8601(week_end)

    rows =
      case File.read(@timesheet_path) do
        {:ok, content} ->
          content
          |> String.split("\n")
          |> Enum.map(&parse_timesheet_row/1)
          |> Enum.reject(&is_nil/1)
          |> Enum.filter(&(&1.date >= start_str && &1.date <= end_str))
          |> Enum.sort_by(& &1.date)

        _ ->
          []
      end

    days =
      rows
      |> Enum.group_by(& &1.date)
      |> Enum.sort_by(fn {date, _} -> date end)
      |> Enum.map(fn {date, day_rows} ->
        %{
          date:     date,
          day_name: hd(day_rows).day_name,
          rows:     day_rows,
          total:    day_rows |> Enum.map(& &1.hours) |> Enum.sum()
        }
      end)

    %{
      days:  days,
      total: rows |> Enum.map(& &1.hours) |> Enum.sum()
    }
  end

  # Parses: | 2026-03-26 | Thursday | Project | 1.5 | desc |
  defp parse_timesheet_row(line) do
    case Regex.run(~r/^\|\s*(\d{4}-\d{2}-\d{2})\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*([\d.]+)\s*\|\s*([^|]*?)\s*\|/, line) do
      [_, date, day_name, project, hours, desc] ->
        case Float.parse(hours) do
          {h, _} ->
            %{
              date:        date,
              day_name:    String.trim(day_name),
              project:     String.trim(project),
              hours:       h,
              description: String.trim(desc)
            }

          :error ->
            nil
        end

      _ ->
        nil
    end
  end

  # ---------------------------------------------------------------------------
  # Project progress (non-live)
  # ---------------------------------------------------------------------------

  defp build_projects_progress(week_start, week_end) do
    since = Date.to_iso8601(week_start)
    until = Date.to_iso8601(Date.add(week_end, 1))

    Hub.ProjectScanner.scan()
    |> Enum.filter(&status_changed_in_git?(&1, since, until))
    |> Enum.sort_by(&(-&1.progress))
  end

  # ---------------------------------------------------------------------------
  # Changed projects
  # ---------------------------------------------------------------------------

  defp build_changed_projects(week_start, week_end) do
    since = Date.to_iso8601(week_start)
    until = Date.to_iso8601(Date.add(week_end, 1))

    Hub.ProjectScanner.scan()
    |> Enum.filter(&status_changed_in_git?(&1, since, until))
    |> Enum.map(fn project ->
      status_path = Path.join(project.path, "STATUS.md")
      content     = File.read!(status_path)
      Map.put(project, :checklist, parse_checklist(content))
    end)
  end

  defp status_changed_in_git?(project, since, until) do
    git_path = project.git_path || project.path

    git_changed =
      case System.cmd(
             "git",
             ["log", "--since=#{since}", "--until=#{until}", "--", "STATUS.md"],
             cd: git_path,
             stderr_to_stdout: true
           ) do
        {output, 0} -> String.trim(output) != ""
        _ -> false
      end

    git_changed || status_mtime_in_range?(project.path, since, until)
  end

  defp status_mtime_in_range?(project_path, since, until) do
    status_path = Path.join(project_path, "STATUS.md")

    case File.stat(status_path) do
      {:ok, %{mtime: mtime}} ->
        {local_date, _} = :calendar.universal_time_to_local_time(mtime)
        date = Date.from_erl!(local_date) |> Date.to_iso8601()
        date >= since && date < until

      _ ->
        false
    end
  end

  defp parse_checklist(content) do
    lines = String.split(content, "\n")
    idx   = Enum.find_index(lines, &String.match?(&1, ~r/^## Checklist/i))

    case idx do
      nil ->
        []

      i ->
        lines
        |> Enum.drop(i + 1)
        |> Enum.take_while(&(!String.match?(&1, ~r/^## /)))
        |> Enum.filter(&String.match?(&1, ~r/^\s*- \[[x ]\]/i))
        |> Enum.map(fn line ->
          done = String.match?(line, ~r/^\s*- \[x\]/i)
          text = Regex.replace(~r/^\s*- \[[x ]\]\s*/i, line, "") |> String.trim()
          %{done: done, text: text}
        end)
    end
  end
end
