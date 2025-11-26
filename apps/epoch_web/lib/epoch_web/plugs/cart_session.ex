defmodule EpochWeb.Plugs.CartSession do
  @moduledoc """
  Plug that ensures a cart session ID exists in the browser session.

  This allows the cart session to persist across page navigations,
  so users don't lose their cart when navigating between products and cart pages.
  """
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_session(conn, :cart_session_id) do
      nil ->
        session_id = Ecto.UUID.generate()
        Epoch.Cart.create_session(session_id)
        put_session(conn, :cart_session_id, session_id)

      _existing ->
        conn
    end
  end
end
