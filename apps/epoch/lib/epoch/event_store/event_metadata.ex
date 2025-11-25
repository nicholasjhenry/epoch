defmodule Epoch.EventStore.EventMetadata do
  @moduledoc """
  System metadata attached to every event envelope.

  Contains:
  - `event_id` - Unique UUID v4 identifier for this event
  - `stream_position` - Position within the stream (1-indexed)
  - `log_position` - Global position across all streams (1-indexed)
  """

  @type t :: %__MODULE__{
          event_id: String.t(),
          stream_position: pos_integer(),
          log_position: pos_integer()
        }

  @enforce_keys [:event_id, :stream_position, :log_position]
  defstruct [:event_id, :stream_position, :log_position]
end
