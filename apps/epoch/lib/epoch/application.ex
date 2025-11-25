defmodule Epoch.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Epoch.Repo,
      {DNSCluster, query: Application.get_env(:epoch, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Epoch.PubSub},
      Epoch.EventStore
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Epoch.Supervisor)
  end
end
