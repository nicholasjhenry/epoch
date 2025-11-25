# Script for populating the event_store. You can run it as:
#
#     mix run priv/event_store/seeds.exs
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

IO.puts("Seeding EventStore with demo data...")

# --- Order Stream: Complete order lifecycle ---
order_id = "order-demo-001"
order_stream = "order-#{order_id}"

{:ok, _} =
  EventStore.append_to_stream(order_stream, [
    %SeedEvents.OrderPlaced{
      order_id: order_id,
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
  EventStore.append_to_stream(order_stream, [
    %SeedEvents.OrderConfirmed{
      order_id: order_id,
      confirmed_at: ~U[2024-01-15 10:35:00Z]
    }
  ])

{:ok, _} =
  EventStore.append_to_stream(order_stream, [
    %SeedEvents.OrderShipped{
      order_id: order_id,
      tracking_number: "1Z999AA10123456784",
      carrier: "UPS",
      shipped_at: ~U[2024-01-16 14:20:00Z]
    }
  ])

{:ok, _} =
  EventStore.append_to_stream(order_stream, [
    %SeedEvents.OrderDelivered{
      order_id: order_id,
      delivered_at: ~U[2024-01-18 09:45:00Z]
    }
  ])

IO.puts("  Created order stream: #{order_stream} (4 events)")

# --- Counter Stream: Simple increment/decrement pattern ---
counter_stream = "counter-demo-001"

events = [
  %SeedEvents.CounterIncremented{amount: 10},
  %SeedEvents.CounterIncremented{amount: 5},
  %SeedEvents.CounterDecremented{amount: 3},
  %SeedEvents.CounterIncremented{amount: 7},
  %SeedEvents.CounterDecremented{amount: 2},
  %SeedEvents.CounterIncremented{amount: 1}
]

{:ok, _} = EventStore.append_to_stream(counter_stream, events)

IO.puts("  Created counter stream: #{counter_stream} (6 events, final value: 18)")

# --- User Activity Stream: User lifecycle events ---
user_id = "user-demo-001"
user_stream = "user-#{user_id}"

{:ok, _} =
  EventStore.append_to_stream(user_stream, [
    %SeedEvents.UserRegistered{
      user_id: user_id,
      email: "alice@example.com",
      registered_at: ~U[2024-01-10 08:00:00Z]
    }
  ])

{:ok, _} =
  EventStore.append_to_stream(user_stream, [
    %SeedEvents.UserEmailChanged{
      user_id: user_id,
      old_email: "alice@example.com",
      new_email: "alice.smith@example.com",
      changed_at: ~U[2024-01-20 16:30:00Z]
    }
  ])

IO.puts("  Created user stream: #{user_stream} (2 events)")

# --- Summary ---
streams = EventStore.debug_all_streams()
total_events = streams |> Map.values() |> Enum.sum()

IO.puts("")
IO.puts("EventStore seeding complete!")
IO.puts("  Total streams: #{map_size(streams)}")
IO.puts("  Total events: #{total_events}")
IO.puts("")
IO.puts("Try these in IEx:")
IO.puts("  EventStore.read_stream(\"#{order_stream}\")")
IO.puts("  EventStore.read_stream(\"#{counter_stream}\")")
IO.puts("  EventStore.debug_all_streams()")
