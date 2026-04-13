defmodule HubWeb.PortfolioBriefingController do
  use HubWeb, :controller

  @briefing_path Path.expand("~/Desktop/Claude/portfolio/project-briefing.html")
  @timesheet_path Path.expand("~/Desktop/Claude/timesheet/timesheet.md")
  @projects_base Path.expand("~/Desktop/Claude")
  @default_rate 0.65
  @buffer 1.40

  @projects [
    %{token: "emdr",      folder: "EMDR",      ts: ["EMDR"],                               blocked: []},
    %{token: "docuforge", folder: "docu_forge", ts: ["DocuForge"],                          blocked: ["SMTP provider", "disk encryption"]},
    %{token: "silence",   folder: "silence",    ts: ["Silence"],                            blocked: []},
    %{token: "security",  folder: "security",   ts: ["Security"],                           blocked: ["Pi hardware"]},
    %{token: "social",    folder: "social",     ts: ["social", "Social"],                   blocked: []},
    %{token: "safe",      folder: "safe",       ts: ["Safe"],                               blocked: []},
    %{token: "pill",      folder: "pill",       ts: ["Pill"],                               blocked: []},
    %{token: "mileage",   folder: "test1",      ts: ["mileage_tracker", "Mileage Tracker"], blocked: []},
    %{token: "ifs",       folder: "ifs",        ts: ["IFS", "ifs"],                         blocked: []},
    %{token: "verdancy",  folder: "Verdancy",   ts: ["Verdancy"],                           blocked: []},
    %{token: "teagles",   folder: "teagles",    ts: ["teagles", "Teagles"],                 blocked: ["Torey feedback"]},
    %{token: "lemonaid",  folder: "lemonade",   ts: ["Lemonade", "lemonade"],               blocked: ["client content"]},
    %{token: "palani",    folder: "palani",     ts: ["Palani", "palani"],                   blocked: []},
    %{token: "spotlight", folder: "spotlight",  ts: ["Spotlight"],                          blocked: []},
    %{token: "hub",        folder: "hub",        ts: ["Hub"],                                blocked: []},
    %{token: "golden",     folder: "Golden",     ts: ["Golden", "Golden Hour"],              blocked: []},
    %{token: "dying",      folder: "Dying",      ts: ["Dying"],                              blocked: []},
    %{token: "negligible9",folder: "Negligible9",ts: ["Negligible9"],                        blocked: []},
    %{token: "wet",        folder: "Wet",        ts: ["Wet"],                                blocked: []},
    %{token: "short",      folder: "Short",      ts: ["Short"],                              blocked: []},
    %{token: "dream",      folder: "Dream",      ts: ["Dream", "Dream Weaver"],              blocked: []},
    %{token: "atomnus",    folder: "Atomnus",    ts: ["Atomnus"],                            blocked: []},
    %{token: "reflectare", folder: "Reflectare", ts: ["Reflectare"],                         blocked: []},
    %{token: "invasion5",  folder: "Invasion5",  ts: ["Invasion5"],                          blocked: []},
    %{token: "bermuda",    folder: "Bermuda",     ts: ["Bermuda"],                            blocked: []},
    %{token: "qlink",      folder: "Qlink",       ts: ["Qlink"],                              blocked: []},
    %{token: "relative",   folder: "Relative",    ts: ["Relative"],                           blocked: []}
  ]

  def show(conn, _params) do
    case File.read(@briefing_path) do
      {:ok, html} ->
        conn
        |> put_resp_content_type("text/html")
        |> send_resp(200, inject_tokens(html))

      {:error, _} ->
        conn
        |> put_resp_content_type("text/html")
        |> send_resp(404, "<p>Portfolio briefing not found at #{@briefing_path}</p>")
    end
  end

  defp inject_tokens(html) do
    timesheet_hours = parse_timesheet()

    project_data =
      Map.new(@projects, fn p ->
        hours = p.ts |> Enum.map(&Map.get(timesheet_hours, &1, 0.0)) |> Enum.sum()
        {completed, remaining} = parse_checklist(p.folder)
        status = parse_status(p.folder)
        next_action = parse_next_action(p.folder)
        rate = if completed > 0 and hours > 0, do: hours / completed, else: @default_rate
        est_hours = Float.round(remaining * rate * @buffer, 1)

        {p.token, %{
          status: status,
          next_action: next_action,
          completed: completed,
          remaining: remaining,
          hours: hours,
          rate: Float.round(rate, 2),
          est_hours: est_hours,
          blocked: p.blocked
        }}
      end)

    active_count =
      Enum.count(project_data, fn {_, d} ->
        d.status not in ["🗄️ Archived", "⏸️ Paused"]
      end)

    date_str = Calendar.strftime(Date.utc_today(), "%B %d, %Y")
    week_data_script = build_week_data_script()

    html
    |> String.replace("{{generated_date}}", date_str)
    |> String.replace("{{project_count}}", to_string(active_count))
    |> String.replace("{{week_data_json}}", week_data_script)
    |> then(&replace_project_tokens(&1, project_data))
  end

  defp replace_project_tokens(html, project_data) do
    Enum.reduce(project_data, html, fn {token, d}, acc ->
      blocked_note =
        case d.blocked do
          [] -> ""
          flags -> " &middot; &#x26A0;&#xFE0F; #{Enum.join(flags, ", ")}"
        end

      confidence = if d.hours < 2.0, do: " (limited data)", else: ""

      est_display =
        if d.remaining == 0, do: "&#x2713; Complete", else: "~#{d.est_hours}h#{confidence}"

      est_detail =
        "#{d.remaining} items remaining &middot; #{d.rate}h/item avg &middot; +40% buffer &middot; estimate only#{blocked_note}"

      est_block = """
      <div class="est-block">
        <div class="est-left">
          <span class="est-label">Est. hours to completion</span>
          <span class="est-val">#{est_display}</span>
        </div>
        <div class="est-right">
          <span class="est-label">Next steps</span>
          <span class="est-state">#{d.next_action}</span>
        </div>
        <div class="est-detail">#{est_detail}</div>
      </div>\
      """

      acc
      |> String.replace("{{status:#{token}}}", d.status)
      |> String.replace("{{est_block:#{token}}}", est_block)
    end)
  end

  # ── Timesheet ─────────────────────────────────────────────────────────────

  defp parse_timesheet do
    case File.read(@timesheet_path) do
      {:ok, content} ->
        content
        |> String.split("\n")
        |> Enum.reduce(%{}, fn line, acc ->
          case Regex.run(~r/^\|\s*\d{4}-\d{2}-\d{2}\s*\|\s*\S+\s*\|\s*([^|]+?)\s*\|\s*([\d.]+)\s*\|/, line) do
            [_, project, hours_str] ->
              Map.update(acc, String.trim(project), parse_float(hours_str), &(&1 + parse_float(hours_str)))
            _ ->
              acc
          end
        end)

      {:error, _} ->
        %{}
    end
  end

  defp parse_float(str) do
    case Float.parse(str) do
      {val, _} -> val
      :error ->
        case Integer.parse(str) do
          {val, _} -> val * 1.0
          :error -> 0.0
        end
    end
  end

  # ── Week Data ─────────────────────────────────────────────────────────────

  defp build_week_data_script do
    week_map =
      case File.read(@timesheet_path) do
        {:ok, content} ->
          content
          |> String.split("\n")
          |> Enum.reduce(%{}, fn line, acc ->
            case Regex.run(~r/^\|\s*(\d{4}-\d{2}-\d{2})\s*\|\s*\S+\s*\|\s*([^|]+?)\s*\|/, line) do
              [_, date_str, project_name] ->
                with {:ok, date} <- Date.from_iso8601(date_str),
                     token when not is_nil(token) <- name_to_token(String.trim(project_name)) do
                  week_key = date |> week_monday() |> Date.to_iso8601()
                  Map.update(acc, week_key, [token], fn tokens ->
                    if token in tokens, do: tokens, else: [token | tokens]
                  end)
                else
                  _ -> acc
                end
              _ -> acc
            end
          end)

        {:error, _} -> %{}
      end

    all_tokens = @projects |> Enum.map(& &1.token) |> Jason.encode!()
    week_data  = Jason.encode!(week_map)

    "<script>\nconst WEEK_DATA = #{week_data};\nconst ALL_TOKENS = #{all_tokens};\n</script>"
  end

  defp week_monday(date) do
    Date.add(date, -(Date.day_of_week(date) - 1))
  end

  defp name_to_token(name) do
    Enum.find_value(@projects, fn p ->
      if name in p.ts, do: p.token, else: nil
    end)
  end

  # ── STATUS.md ─────────────────────────────────────────────────────────────

  defp read_status_md(folder) do
    path = Path.join([@projects_base, folder, "STATUS.md"])
    case File.read(path) do
      {:ok, content} -> content
      {:error, _} -> ""
    end
  end

  defp parse_status(folder) do
    case Regex.run(~r/\*\*Status:\*\*\s*(.+)/, read_status_md(folder)) do
      [_, s] -> String.trim(s)
      _ -> "Unknown"
    end
  end

  defp parse_next_action(folder) do
    case Regex.run(~r/## Next Action\r?\n(.+)/, read_status_md(folder)) do
      [_, a] -> String.trim(a)
      _ -> "—"
    end
  end

  defp parse_checklist(folder) do
    content = read_status_md(folder)
    lines = String.split(content, "\n")
    completed = Enum.count(lines, &Regex.match?(~r/- \[x\]/i, &1))
    remaining = Enum.count(lines, &Regex.match?(~r/- \[ \]/, &1))
    {completed, remaining}
  end
end
