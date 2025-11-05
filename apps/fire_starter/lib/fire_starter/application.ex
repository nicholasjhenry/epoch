defmodule FireStarter.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      FireStarter.Repo,
      {DNSCluster, query: Application.get_env(:fire_starter, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: FireStarter.PubSub}
      # Start a worker by calling: FireStarter.Worker.start_link(arg)
      # {FireStarter.Worker, arg}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: FireStarter.Supervisor)
  end
end
