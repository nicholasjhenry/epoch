# EventsLive Contract Extension
#
# This file documents the contract additions to the EventsLive LiveView
# for Feature 004: Default Event List
#
# File: apps/epoch_web/lib/epoch_web/live/dev/events_live.ex

defmodule EpochWeb.Dev.EventsLive.Contracts.Feature004 do
  @moduledoc """
  Contract specification for EventsLive modifications.

  This extends the existing EventsLive to support viewing all events
  by default on initial load.
  """

  # =============================================================================
  # Assigns Contract
  # =============================================================================

  @typedoc """
  View mode for the event viewer.

  - `:all` - Viewing all events (default on mount)
  - `:filtered` - Viewing events filtered by stream type
  """
  @type view_mode :: :all | :filtered

  @doc """
  New and modified assigns for Feature 004.

  ## New Assigns

  | Assign | Type | Default | Description |
  |--------|------|---------|-------------|
  | `:view_mode` | `view_mode()` | `:all` | Current view state |

  ## Modified Behavior

  | Assign | Previous | New |
  |--------|----------|-----|
  | `:events` | Empty on mount | Loaded from `read_all_events/2` |
  | `:total` | `0` | From `read_all_events/2` result |
  | `:has_more` | `false` | From `read_all_events/2` result |
  | `:events_empty?` | `true` | Computed from result |
  """

  # =============================================================================
  # Mount Contract
  # =============================================================================

  @doc """
  Mount behavior with default event loading.

  ## Previous Behavior

  - Mounted with empty events list
  - Required user to enter filter to see events
  - Displayed "Enter a stream type to view events"

  ## New Behavior

  1. Subscribe to "all_events" topic (if connected)
  2. Call `EventStore.read_all_events(page: 1)`
  3. Populate events stream with results
  4. Set `view_mode: :all`
  5. Display all events immediately

  ## Assigns on Mount

      %{
        view_mode: :all,
        stream_type: nil,
        page: 1,
        page_size: 20,
        has_more: <from result>,
        total: <from result>,
        events_empty?: <events == []>,
        events: <stream with events>
      }
  """

  # =============================================================================
  # Event Handlers Contract
  # =============================================================================

  @doc """
  Filter event handler modifications.

  ## "filter" Event

  When user applies a stream type filter:

  1. Validate stream_type is non-empty
  2. Unsubscribe from current topic:
     - If `view_mode == :all`: unsubscribe "all_events"
     - If `view_mode == :filtered`: unsubscribe "stream_type:{old_type}"
  3. Subscribe to "stream_type:{new_type}"
  4. Call `read_by_stream_type(type, page: 1)`
  5. Update assigns:
     - `view_mode: :filtered`
     - `stream_type: type`
     - `page: 1`
     - Results from query

  ## "clear_filter" Event

  When user clears the filter:

  1. Unsubscribe from "stream_type:{current_type}"
  2. Subscribe to "all_events"
  3. Call `read_all_events(page: 1)`
  4. Update assigns:
     - `view_mode: :all`
     - `stream_type: nil`
     - `page: 1`
     - Results from query
  """

  # =============================================================================
  # Info Handlers Contract
  # =============================================================================

  @doc """
  PubSub message handler.

  Handles `{:events_appended, stream_name, events}` from both topics.

  ## Behavior

  Same as existing implementation:
  - Only update UI if on page 1
  - Prepend new events to stream
  - Update total count
  - Set events_empty? to false

  ## No Changes Required

  The existing handler works for both topics since the message format
  is identical. The handler already:
  - Extracts events from EventEnvelope structs
  - Adds stream_name to event map
  - Prepends to stream at position 0
  """

  # =============================================================================
  # Template Contract
  # =============================================================================

  @doc """
  Empty state message logic.

  ## Previous Logic

      "Enter a stream type to view events"  # Always shown when empty

  ## New Logic

      cond do
        view_mode == :all and events_empty? ->
          "No events in store"

        view_mode == :filtered and events_empty? ->
          "No events match filter '\#{stream_type}'"

        true ->
          # Show events
      end

  ## UI Changes

  - Remove "Enter a stream type" prompt
  - Show events immediately on load
  - Clear filter button appears when `view_mode == :filtered`
  """
end
