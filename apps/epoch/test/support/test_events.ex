defmodule Epoch.EventStore.TestEvents do
  @moduledoc """
  Sample event types for testing the EventStore.

  These events represent common patterns in event-sourced systems:
  - Order lifecycle events (OrderPlaced, OrderShipped, OrderCancelled)
  - Counter events (CounterIncremented, CounterDecremented)
  """

  defmodule OrderPlaced do
    @moduledoc "Event representing a new order being placed"
    defstruct [:order_id, :customer_id, :items, :total]

    @type t :: %__MODULE__{
            order_id: String.t(),
            customer_id: String.t(),
            items: [String.t()],
            total: float()
          }
  end

  defmodule OrderShipped do
    @moduledoc "Event representing an order being shipped"
    defstruct [:order_id, :tracking_number, :carrier]

    @type t :: %__MODULE__{
            order_id: String.t(),
            tracking_number: String.t(),
            carrier: String.t()
          }
  end

  defmodule OrderCancelled do
    @moduledoc "Event representing an order being cancelled"
    defstruct [:order_id, :reason]

    @type t :: %__MODULE__{
            order_id: String.t(),
            reason: String.t()
          }
  end

  defmodule CounterIncremented do
    @moduledoc "Event representing a counter being incremented"
    defstruct [:amount]

    @type t :: %__MODULE__{
            amount: pos_integer()
          }
  end

  defmodule CounterDecremented do
    @moduledoc "Event representing a counter being decremented"
    defstruct [:amount]

    @type t :: %__MODULE__{
            amount: pos_integer()
          }
  end
end
