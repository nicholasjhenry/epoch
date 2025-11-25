# Script for populating the event_store. You can run it as:
#
#     mix run apps/epoch/priv/event_store/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Epoch.Repo.insert!(%Epoch.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

# =============================================================================
# EventStore Demo Data
# =============================================================================
#
# This section populates the in-memory EventStore with sample event streams
# demonstrating typical usage patterns.

alias Epoch.EventStore

alias Epoch.SeedEvents.{
  OrderPlaced,
  OrderConfirmed,
  OrderShipped,
  OrderDelivered,
  CounterIncremented,
  CounterDecremented,
  UserRegistered,
  UserEmailChanged,
  CartCreated,
  ItemAddedToCart
}

IO.puts("Seeding EventStore with demo data...")

# =============================================================================
# Order Streams (5 total)
# =============================================================================

# --- Order 1: Complete lifecycle ---
order_stream_1 = "order-demo-001"

{:ok, _} =
  EventStore.append_to_stream(order_stream_1, [
    %OrderPlaced{
      order_id: "demo-001",
      customer_id: "customer-42",
      items: [
        %{sku: "WIDGET-001", name: "Blue Widget", quantity: 2, price: 29.99},
        %{sku: "GADGET-003", name: "Smart Gadget", quantity: 1, price: 149.99}
      ],
      total: 209.97,
      placed_at: ~U[2024-01-15 10:30:00Z]
    }
  ])

{:ok, _} =
  EventStore.append_to_stream(order_stream_1, [
    %OrderConfirmed{order_id: "demo-001", confirmed_at: ~U[2024-01-15 10:35:00Z]}
  ])

{:ok, _} =
  EventStore.append_to_stream(order_stream_1, [
    %OrderShipped{
      order_id: "demo-001",
      tracking_number: "1Z999AA10123456784",
      carrier: "UPS",
      shipped_at: ~U[2024-01-16 14:20:00Z]
    }
  ])

{:ok, _} =
  EventStore.append_to_stream(order_stream_1, [
    %OrderDelivered{order_id: "demo-001", delivered_at: ~U[2024-01-18 09:45:00Z]}
  ])

IO.puts("  Created order stream: #{order_stream_1} (4 events)")

# --- Orders 2-5: Various stages ---
for i <- 2..5 do
  order_id = "demo-00#{i}"
  stream = "order-#{order_id}"

  {:ok, _} =
    EventStore.append_to_stream(stream, [
      %OrderPlaced{
        order_id: order_id,
        customer_id: "customer-#{10 + i}",
        items: [%{sku: "ITEM-#{i}", name: "Product #{i}", quantity: i, price: 19.99 * i}],
        total: 19.99 * i,
        placed_at: DateTime.add(~U[2024-01-15 10:30:00Z], i * 3600, :second)
      }
    ])

  {:ok, _} =
    EventStore.append_to_stream(stream, [
      %OrderConfirmed{
        order_id: order_id,
        confirmed_at: DateTime.add(~U[2024-01-15 11:00:00Z], i * 3600, :second)
      }
    ])

  if i > 2 do
    {:ok, _} =
      EventStore.append_to_stream(stream, [
        %OrderShipped{
          order_id: order_id,
          tracking_number: "1Z999AA1012345678#{i}",
          carrier: "FedEx",
          shipped_at: DateTime.add(~U[2024-01-16 14:20:00Z], i * 3600, :second)
        }
      ])
  end

  event_count = if i > 2, do: 3, else: 2
  IO.puts("  Created order stream: #{stream} (#{event_count} events)")
end

# =============================================================================
# Cart Streams (3 total)
# =============================================================================

for i <- 1..3 do
  cart_id = "demo-00#{i}"
  stream = "cart-#{cart_id}"

  {:ok, _} =
    EventStore.append_to_stream(stream, [
      %CartCreated{
        cart_id: cart_id,
        user_id: "user-#{20 + i}",
        created_at: DateTime.add(~U[2024-01-14 09:00:00Z], i * 7200, :second)
      }
    ])

  {:ok, _} =
    EventStore.append_to_stream(stream, [
      %ItemAddedToCart{cart_id: cart_id, sku: "WIDGET-00#{i}", quantity: i, price: 29.99}
    ])

  if i > 1 do
    {:ok, _} =
      EventStore.append_to_stream(stream, [
        %ItemAddedToCart{cart_id: cart_id, sku: "GADGET-00#{i}", quantity: 1, price: 49.99}
      ])
  end

  event_count = if i > 1, do: 3, else: 2
  IO.puts("  Created cart stream: #{stream} (#{event_count} events)")
end

# =============================================================================
# User Streams (2 total)
# =============================================================================

user_stream_1 = "user-demo-001"

{:ok, _} =
  EventStore.append_to_stream(user_stream_1, [
    %UserRegistered{
      user_id: "demo-001",
      email: "alice@example.com",
      registered_at: ~U[2024-01-10 08:00:00Z]
    }
  ])

{:ok, _} =
  EventStore.append_to_stream(user_stream_1, [
    %UserEmailChanged{
      user_id: "demo-001",
      old_email: "alice@example.com",
      new_email: "alice.smith@example.com",
      changed_at: ~U[2024-01-20 16:30:00Z]
    }
  ])

IO.puts("  Created user stream: #{user_stream_1} (2 events)")

user_stream_2 = "user-demo-002"

{:ok, _} =
  EventStore.append_to_stream(user_stream_2, [
    %UserRegistered{
      user_id: "demo-002",
      email: "bob@example.com",
      registered_at: ~U[2024-01-12 14:00:00Z]
    }
  ])

IO.puts("  Created user stream: #{user_stream_2} (1 event)")

# =============================================================================
# Counter Stream (1 total - bonus demo)
# =============================================================================

counter_stream = "counter-demo-001"

events = [
  %CounterIncremented{amount: 10},
  %CounterIncremented{amount: 5},
  %CounterDecremented{amount: 3},
  %CounterIncremented{amount: 7},
  %CounterDecremented{amount: 2},
  %CounterIncremented{amount: 1}
]

{:ok, _} = EventStore.append_to_stream(counter_stream, events)

IO.puts("  Created counter stream: #{counter_stream} (6 events, final value: 18)")

# =============================================================================
# Summary
# =============================================================================

streams = EventStore.debug_all_streams()
total_events = streams |> Map.values() |> Enum.sum()

IO.puts("")
IO.puts("EventStore seeding complete!")
IO.puts("  Total streams: #{map_size(streams)}")
IO.puts("  Total events: #{total_events}")
IO.puts("")
IO.puts("Stream type breakdown:")
IO.puts("  order-*: 5 streams")
IO.puts("  cart-*: 3 streams")
IO.puts("  user-*: 2 streams")
IO.puts("  counter-*: 1 stream")
IO.puts("")
IO.puts("Try the stream type filter at: http://localhost:4000/dev/events")
IO.puts("")
IO.puts("Try these in IEx:")
IO.puts("  EventStore.read_stream(\"order-demo-001\")")
IO.puts("  EventStore.read_by_stream_type(\"order\")")
IO.puts("  EventStore.read_by_stream_type(\"cart\")")
IO.puts("  EventStore.debug_all_streams()")
