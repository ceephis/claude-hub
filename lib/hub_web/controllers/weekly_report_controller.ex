defmodule HubWeb.WeeklyReportController do
  use HubWeb, :controller

  def show(conn, params) do
    week_start = Hub.WeeklyReport.week_start_from_param(params["week"])
    report     = Hub.WeeklyReport.build(week_start)
    {prev_week, next_week} = Hub.WeeklyReport.adjacent_weeks(week_start)

    render(conn, :show,
      report:    report,
      prev_week: prev_week,
      next_week: next_week
    )
  end
end
