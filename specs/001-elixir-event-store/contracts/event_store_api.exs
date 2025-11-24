# Event Store API Contract
# Feature: 001-elixir-event-store
# Date: 2025-11-24

# This file documents the public API contract for Epoch.EventStore.
# It serves as both documentation and a reference for implementation.

defmodule Epoch.EventStore.Contract do
  @moduledoc """
  Public API contract for the in-memory event store.

  This module documents the expected function signatures, return types,
  and error cases for the event store implementation.
  """

  # ===========================================================================
  # GenServer Lifecycle
  # ===========================================================================

  @doc """
  Starts the EventStore GenServer.

  The EventStore is typically started as part of the application supervision tree.

  ## Options

  - `:name` - The name to register the GenServer under (default: Epoch.EventStore)

  ## Examples

      {:ok, pid} = Epoch.EventStore.start_link(name: Epoch.EventStore)
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ [])

  # ===========================================================================
  # Core Operations
  # ===========================================================================

  @doc """
  Appends one or more events to a stream.

  Events are appended atomically - either all events are added or none are.
  Each event is wrapped in an EventEnvelope with system metadata.

  ## Arguments

  - `stream_name` - Name of the stream (string)
  - `events` - List of events to append (any Elixir term)
  - `opts` - Options:
    - `:expected_version` - Expected current version for optimistic concurrency control
      - `nil` (default) - No version check, append unconditionally
      - `0` - Expect stream to be empty or non-existent
      - `N > 0` - Expect stream to have exactly N events

  ## Returns

  - `{:ok, %{next_expected_version: integer()}}` - Success, returns new version
  - `{:error, %VersionMismatchError{}}` - Version conflict detected

  ## Examples

      # Unconditional append
      {:ok, %{next_expected_version: 3}} =
        Epoch.EventStore.append_to_stream("order-123", [event1, event2, event3])

      # With optimistic concurrency control
      {:ok, %{next_expected_version: 4}} =
        Epoch.EventStore.append_to_stream("order-123", [event4], expected_version: 3)

      # Version mismatch
      {:error, %VersionMismatchError{expected_version: 5, current_version: 3}} =
        Epoch.EventStore.append_to_stream("order-123", [event], expected_version: 5)
  """
  @spec append_to_stream(
          stream_name :: String.t(),
          events :: [term()],
          opts :: keyword()
        ) ::
          {:ok, %{next_expected_version: non_neg_integer()}}
          | {:error, Epoch.EventStore.VersionMismatchError.t()}
  def append_to_stream(stream_name, events, opts \\ [])

  @doc """
  Reads events from a stream.

  Returns events in the order they were appended. Supports pagination for
  reading subsets of large streams.

  ## Arguments

  - `stream_name` - Name of the stream (string)
  - `opts` - Options:
    - `:from` - Starting position (0-indexed, default: 0)
    - `:to` - Ending position (exclusive, default: end of stream)
    - `:max_count` - Maximum number of events to return (alternative to `:to`)
    - `:expected_version` - Verify stream version before reading (optional)

  Note: Either specify `:to` or `:max_count`, not both.

  ## Returns

  - `{:ok, %{events: [term()], version: non_neg_integer()}}` - Success
  - `{:error, :stream_not_found}` - Stream does not exist
  - `{:error, :invalid_pagination}` - Invalid pagination parameters
  - `{:error, %VersionMismatchError{}}` - Version check failed

  ## Examples

      # Read all events
      {:ok, %{events: events, version: 5}} =
        Epoch.EventStore.read_stream("order-123")

      # Read events 10-20
      {:ok, %{events: events, version: 100}} =
        Epoch.EventStore.read_stream("order-123", from: 10, to: 20)

      # Read first 10 events
      {:ok, %{events: events, version: 100}} =
        Epoch.EventStore.read_stream("order-123", from: 0, max_count: 10)

      # Read with version check
      {:ok, %{events: events, version: 5}} =
        Epoch.EventStore.read_stream("order-123", expected_version: 5)
  """
  @spec read_stream(
          stream_name :: String.t(),
          opts :: keyword()
        ) ::
          {:ok, %{events: [term()], version: non_neg_integer()}}
          | {:error,
             :stream_not_found | :invalid_pagination | Epoch.EventStore.VersionMismatchError.t()}
  def read_stream(stream_name, opts \\ [])

  @doc """
  Aggregates a stream by applying an evolve function to each event.

  This is a convenience function that combines reading a stream with reducing
  events to produce final state. Supports the same pagination options as read_stream.

  ## Arguments

  - `stream_name` - Name of the stream (string)
  - `initial_state` - Starting state for the reduction
  - `evolve_fun` - Function to apply: `(state, event) -> new_state`
  - `opts` - Same options as read_stream (pagination, version check)

  ## Returns

  - `{:ok, %{state: term(), version: non_neg_integer()}}` - Success
  - `{:error, :stream_not_found}` - Stream does not exist
  - `{:error, :invalid_pagination}` - Invalid pagination parameters
  - `{:error, %VersionMismatchError{}}` - Version check failed

  ## Examples

      # Sum counter events
      evolve = fn state, %{amount: amount} -> state + amount end
      {:ok, %{state: 42, version: 10}} =
        Epoch.EventStore.aggregate_stream("counter-1", 0, evolve)

      # Build order state from events
      evolve = fn
        state, %OrderPlaced{} = event -> %{state | status: :placed, total: event.total}
        state, %OrderShipped{} = event -> %{state | status: :shipped}
      end
      {:ok, %{state: order_state, version: 3}} =
        Epoch.EventStore.aggregate_stream("order-123", %{}, evolve)

      # Aggregate with pagination (partial state)
      {:ok, %{state: partial_state, version: 100}} =
        Epoch.EventStore.aggregate_stream("order-123", %{}, evolve, max_count: 10)
  """
  @spec aggregate_stream(
          stream_name :: String.t(),
          initial_state :: term(),
          evolve_fun :: (state :: term(), event :: term() -> term()),
          opts :: keyword()
        ) ::
          {:ok, %{state: term(), version: non_neg_integer()}}
          | {:error,
             :stream_not_found | :invalid_pagination | Epoch.EventStore.VersionMismatchError.t()}
  def aggregate_stream(stream_name, initial_state, evolve_fun, opts \\ [])

  # ===========================================================================
  # Subscriptions
  # ===========================================================================

  @doc """
  Subscribes to a stream to receive notifications when events are appended.

  The callback is invoked immediately with the current stream state (existing events),
  then subsequently whenever events are appended to the stream.

  Callbacks execute synchronously during append operations. Long-running callbacks
  will block appends.

  ## Arguments

  - `stream_name` - Name of the stream to watch (string)
  - `callback` - Function to invoke: `(version, events) -> any()`
    - `version` - New stream version after the events
    - `events` - List of newly appended events (unwrapped, not EventEnvelopes)

  ## Returns

  - `{:ok, subscription_ref}` - Subscription reference (the callback function itself)

  ## Callback Behavior

  - Invoked immediately upon subscription with current stream state
  - Invoked synchronously during each append to the subscribed stream
  - Callback errors are logged but do not prevent append success
  - Callback return values are ignored

  ## Examples

      # Subscribe to order stream
      callback = fn version, events ->
        IO.puts("Order stream updated to version \#{version}")
        Enum.each(events, &process_event/1)
      end

      {:ok, ^callback} = Epoch.EventStore.subscribe("order-123", callback)

      # Later: appending triggers callback
      Epoch.EventStore.append_to_stream("order-123", [new_event])
      # => callback is invoked with (new_version, [new_event])
  """
  @spec subscribe(
          stream_name :: String.t(),
          callback :: (version :: non_neg_integer(), events :: [term()] -> any())
        ) :: {:ok, callback :: function()}
  def subscribe(stream_name, callback)

  @doc """
  Unsubscribes from a stream.

  The callback will no longer be invoked for future appends. Unsubscribing
  is idempotent - unsubscribing an already-removed subscription is safe.

  ## Arguments

  - `stream_name` - Name of the stream (string)
  - `subscription_ref` - The callback function returned from subscribe/2

  ## Returns

  - `:ok` - Always succeeds, even if subscription doesn't exist

  ## Examples

      {:ok, callback} = Epoch.EventStore.subscribe("order-123", my_callback)

      # Later: stop receiving notifications
      :ok = Epoch.EventStore.unsubscribe("order-123", callback)

      # Subsequent appends will not invoke callback
      Epoch.EventStore.append_to_stream("order-123", [event])
      # => callback is NOT invoked
  """
  @spec unsubscribe(
          stream_name :: String.t(),
          subscription_ref :: function()
        ) :: :ok
  def unsubscribe(stream_name, subscription_ref)

  # ===========================================================================
  # Debugging & Introspection
  # ===========================================================================

  @doc """
  Returns a map of all streams and their event counts (for debugging).

  This is intended for debugging and testing. Do not rely on this function
  for production logic.

  ## Returns

  - `%{stream_name => event_count}` - Map of stream names to event counts

  ## Examples

      Epoch.EventStore.debug_all_streams()
      # => %{
      #   "order-123" => 5,
      #   "order-456" => 3,
      #   "counter-1" => 10
      # }
  """
  @spec debug_all_streams() :: %{String.t() => non_neg_integer()}
  def debug_all_streams()
end

# ===========================================================================
# Error Types
# ===========================================================================

defmodule Epoch.EventStore.VersionMismatchError do
  @moduledoc """
  Raised when an append operation's expected version doesn't match the current version.

  This indicates an optimistic concurrency conflict - another process has modified
  the stream since the caller last read it.
  """

  defexception [:stream_name, :expected_version, :current_version, :message]

  @type t :: %__MODULE__{
          stream_name: String.t(),
          expected_version: non_neg_integer(),
          current_version: non_neg_integer(),
          message: String.t()
        }

  @impl true
  def exception(opts) do
    stream_name = Keyword.fetch!(opts, :stream_name)
    expected = Keyword.fetch!(opts, :expected_version)
    current = Keyword.fetch!(opts, :current_version)

    message =
      "Expected stream '#{stream_name}' to be at version #{expected} " <>
        "but found version #{current}"

    %__MODULE__{
      stream_name: stream_name,
      expected_version: expected,
      current_version: current,
      message: message
    }
  end
end

# ===========================================================================
# Type Definitions
# ===========================================================================

defmodule Epoch.EventStore.Types do
  @moduledoc """
  Type definitions for the event store.
  """

  @typedoc "A domain event (any Elixir term)"
  @type event :: term()

  @typedoc "Stream name (non-empty string)"
  @type stream_name :: String.t()

  @typedoc "Stream version (number of events in stream)"
  @type version :: non_neg_integer()

  @typedoc "Event metadata"
  @type event_metadata :: %{
          event_id: String.t(),
          stream_position: pos_integer(),
          log_position: pos_integer()
        }

  @typedoc "Event envelope (internal storage format)"
  @type event_envelope :: %{
          event: event(),
          metadata: event_metadata()
        }

  @typedoc "Subscription callback function"
  @type subscription_callback :: (version :: version(), events :: [event()] -> any())

  @typedoc "Options for append_to_stream"
  @type append_opts :: [
          expected_version: version() | nil
        ]

  @typedoc "Options for read_stream"
  @type read_opts :: [
          from: non_neg_integer(),
          to: non_neg_integer(),
          max_count: pos_integer(),
          expected_version: version() | nil
        ]

  @typedoc "Result of successful append"
  @type append_result :: %{
          next_expected_version: version()
        }

  @typedoc "Result of successful read"
  @type read_result :: %{
          events: [event()],
          version: version()
        }

  @typedoc "Result of successful aggregate"
  @type aggregate_result :: %{
          state: term(),
          version: version()
        }
end
