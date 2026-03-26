defmodule Hub.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      HubWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:hub, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Hub.PubSub},
      Hub.ProjectWatcher,
      HubWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Hub.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    HubWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
