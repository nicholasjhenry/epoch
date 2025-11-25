defmodule Epoch.SeedEvents do
  @moduledoc """
  Event structs for seed data and demos.

  These are simple structs used to populate the EventStore with realistic
  demo data. In production, you would use your actual domain event modules.
  """

  defmodule OrderPlaced do
    @moduledoc "Event: A new order was placed"
    defstruct [:order_id, :customer_id, :items, :total, :placed_at]
  end

  defmodule OrderConfirmed do
    @moduledoc "Event: An order was confirmed"
    defstruct [:order_id, :confirmed_at]
  end

  defmodule OrderShipped do
    @moduledoc "Event: An order was shipped"
    defstruct [:order_id, :tracking_number, :carrier, :shipped_at]
  end

  defmodule OrderDelivered do
    @moduledoc "Event: An order was delivered"
    defstruct [:order_id, :delivered_at]
  end

  defmodule CounterIncremented do
    @moduledoc "Event: A counter was incremented"
    defstruct [:amount]
  end

  defmodule CounterDecremented do
    @moduledoc "Event: A counter was decremented"
    defstruct [:amount]
  end

  defmodule UserRegistered do
    @moduledoc "Event: A new user registered"
    defstruct [:user_id, :email, :registered_at]
  end

  defmodule UserEmailChanged do
    @moduledoc "Event: A user changed their email"
    defstruct [:user_id, :old_email, :new_email, :changed_at]
  end

  defmodule CartCreated do
    @moduledoc "Event: A shopping cart was created"
    defstruct [:cart_id, :user_id, :created_at]
  end

  defmodule ItemAddedToCart do
    @moduledoc "Event: An item was added to a cart"
    defstruct [:cart_id, :sku, :quantity, :price]
  end
end
