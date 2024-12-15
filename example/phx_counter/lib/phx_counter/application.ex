defmodule PhxCounter.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      PhxCounterWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:phx_counter, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: PhxCounter.PubSub},
      # Start a worker by calling: PhxCounter.Worker.start_link(arg)
      # {PhxCounter.Worker, arg},
      # Start to serve requests, typically the last entry
      PhxCounterWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: PhxCounter.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    PhxCounterWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
