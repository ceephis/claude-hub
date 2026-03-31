defmodule HubWeb.Router do
  use HubWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {HubWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", HubWeb do
    pipe_through :browser

    live "/", DashboardLive
    get  "/status-pdf/:folder", StatusExportController, :download
    get  "/weekly-report", WeeklyReportController, :show
  end

  # Other scopes may use custom stacks.
  # scope "/api", HubWeb do
  #   pipe_through :api
  # end

end
