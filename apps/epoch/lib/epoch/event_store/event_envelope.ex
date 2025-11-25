defmodule Epoch.EventStore.EventEnvelope do
  @moduledoc """
  A wrapper around a domain event that adds system metadata.

  This is what gets stored in the event store. The envelope contains:
  - `event` - The actual domain event data (any Elixir term)
  - `metadata` - System-generated metadata (EventMetadata struct)

  Event envelopes are created internally during append operations and are
  never created directly by clients.
  """

  alias Epoch.EventStore.EventMetadata

  @type t :: %__MODULE__{
          event: term(),
          metadata: EventMetadata.t()
        }

  @enforce_keys [:event, :metadata]
  defstruct [:event, :metadata]
end
