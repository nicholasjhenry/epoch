defmodule EpochWeb.CartLive do
  @moduledoc """
  LiveView for the shopping cart page.

  This is the parent container that renders navigation and delegates
  cart item display to the CartItems nested LiveView, which manages
  its own PubSub subscription for real-time updates.
  """
  use EpochWeb, :live_view

  @impl true
  def mount(%{"session_id" => session_id}, _session, socket) do
    socket =
      socket
      |> assign(:session_id, session_id)
      |> assign(:cart_session_id, session_id)

    {:ok, socket}
  end
end
