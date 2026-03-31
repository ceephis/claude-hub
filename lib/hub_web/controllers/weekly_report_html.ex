defmodule HubWeb.WeeklyReportHTML do
  use HubWeb, :html

  embed_templates "weekly_report_html/*"

  def format_hours(h) when is_float(h) do
    int  = trunc(h)
    mins = round((h - int) * 60)
    if mins == 0, do: "#{int}h", else: "#{int}h #{mins}m"
  end

  def format_hours(h), do: "#{h}h"

  def format_date_range(week_start, week_end) do
    "#{Calendar.strftime(week_start, "%b %d")} – #{Calendar.strftime(week_end, "%b %d, %Y")}"
  end

  def status_emoji(:active),   do: "🟢"
  def status_emoji(:planning), do: "🟡"
  def status_emoji(:paused),   do: "🔴"
  def status_emoji(:live),     do: "✅"
  def status_emoji(_),         do: "⚪"
end
