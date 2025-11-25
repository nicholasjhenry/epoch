# EventStore Contract Extension
#
# This file documents the contract additions to the EventStore module
# for Feature 004: Default Event List
#
# File: apps/epoch/lib/epoch/event_store.ex

defmodule Epoch.EventStore.Contracts.Feature004 do
  @moduledoc """
  Contract specification for read_all_events/2 function.

  This extends the existing EventStore API to support reading all events
  across all streams with pagination.
  """

  # =============================================================================
  # Types
  # =============================================================================

  @typedoc """
  Options for read_all_events/2.

  - `:page` - Page number (1-indexed), defaults to 1
  - `:page_size` - Number of events per page (1-100), defaults to 20
  """
  @type read_all_opts :: [
          page: pos_integer(),
          page_size: pos_integer()
        ]

  @typedoc """
  Result structure for read_all_events/2.

  Same structure as read_by_stream_type/3 for consistency.
  """
  @type read_all_result :: %{
          events: [event_with_stream()],
          has_more: boolean(),
          total: non_neg_integer()
        }

  @typedoc """
  Event with stream context, including the source stream name.
  """
  @type event_with_stream :: %{
          event: term(),
          stream_name: String.t(),
          metadata: Epoch.EventStore.EventMetadata.t()
        }

  # =============================================================================
  # Function Specification
  # =============================================================================

  @doc """
  Reads all events from all streams, ordered by global position.

  ## Parameters

  - `server` - The EventStore server (defaults to `Epoch.EventStore`)
  - `opts` - Options keyword list
    - `:page` - Page number, 1-indexed (default: 1)
    - `:page_size` - Events per page (default: 20, max: 100)

  ## Returns

  - `{:ok, result}` where result contains:
    - `:events` - List of events with stream context
    - `:has_more` - Boolean indicating more pages exist
    - `:total` - Total count of all events

  ## Examples

      # Read first page with default size
      {:ok, %{events: events, has_more: true, total: 150}} =
        EventStore.read_all_events()

      # Read second page with custom size
      {:ok, %{events: events, has_more: false, total: 45}} =
        EventStore.read_all_events(page: 2, page_size: 25)

      # Empty store
      {:ok, %{events: [], has_more: false, total: 0}} =
        EventStore.read_all_events()

  ## Implementation Notes

  - Events are sorted by `log_position` (global chronological order)
  - Each event includes `:stream_name` for display purposes
  - Pagination uses offset/limit internally
  - Same validation as read_by_stream_type/3: page >= 1, page_size in 1..100
  """
  @spec read_all_events(GenServer.server(), read_all_opts()) :: {:ok, read_all_result()}
  def read_all_events(server \\ Epoch.EventStore, opts \\ [])

  # =============================================================================
  # PubSub Contract
  # =============================================================================

  @doc """
  PubSub topic for all events.

  The EventStore broadcasts to this topic on every append, in addition to
  the stream-type-specific topic.

  ## Topic

      "all_events"

  ## Message Format

      {:events_appended, stream_name, events}

  Where:
  - `stream_name` - The stream that received the events (e.g., "order-123")
  - `events` - List of `EventEnvelope.t()` structs

  ## Subscription

      Phoenix.PubSub.subscribe(Epoch.PubSub, "all_events")

  ## Usage in LiveView

      def handle_info({:events_appended, stream_name, events}, socket) do
        # Handle new events from any stream
      end
  """
  @all_events_topic "all_events"
  def all_events_topic, do: @all_events_topic
end
