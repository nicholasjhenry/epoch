defmodule Epoch.EventStore.VersionMismatchError do
  @moduledoc """
  Error raised when the expected stream version doesn't match the current version
  during an append operation.

  This error supports optimistic concurrency control by detecting when another
  process has modified a stream between a read and a write operation.
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
    expected_version = Keyword.fetch!(opts, :expected_version)
    current_version = Keyword.fetch!(opts, :current_version)

    message =
      "Expected stream '#{stream_name}' to be at version #{expected_version} " <>
        "but found version #{current_version}"

    %__MODULE__{
      stream_name: stream_name,
      expected_version: expected_version,
      current_version: current_version,
      message: message
    }
  end
end
