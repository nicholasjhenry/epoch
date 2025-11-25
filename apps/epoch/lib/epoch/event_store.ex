defmodule Epoch.EventStore do
  @moduledoc """
  An in-memory event store for event sourcing.

  Provides:
  - Appending events to named streams
  - Reading events with optional pagination
  - Optimistic concurrency control via stream versions
  - Aggregate state reconstruction
  - Stream subscriptions for reactive patterns

  ## Example

      # Append events to a stream
      {:ok, %{next_expected_version: 1}} =
        EventStore.append_to_stream("order-123", [%OrderPlaced{...}])

      # Read events from a stream
      {:ok, %{events: events, version: 1}} =
        EventStore.read_stream("order-123")

      # Append with optimistic concurrency control
      {:ok, %{next_expected_version: 2}} =
        EventStore.append_to_stream("order-123", [%OrderShipped{...}], expected_version: 1)

  """

  use GenServer
  require Logger

  alias Epoch.EventStore.{EventEnvelope, EventMetadata, VersionMismatchError}

  @type stream_name :: String.t()
  @type event :: term()
  @type version :: non_neg_integer()
  @type subscription_callback :: (version(), [event()] -> any())

  # Client API

  @doc """
  Starts the EventStore GenServer.

  ## Options

    * `:name` - The name to register the process under. Defaults to `Epoch.EventStore`.

  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Appends events to a stream.

  ## Options

    * `:expected_version` - The expected current version of the stream.
      If provided and doesn't match the current version, raises `VersionMismatchError`.
      If `nil` (default), appends unconditionally.

  ## Returns

    * `{:ok, %{next_expected_version: version}}` - On success
    * Raises `VersionMismatchError` if version check fails
    * Raises `ArgumentError` if stream_name is empty

  """
  @spec append_to_stream(stream_name(), [event()], keyword()) ::
          {:ok, %{next_expected_version: version()}}
  def append_to_stream(stream_name, events, opts \\ []) do
    append_to_stream(__MODULE__, stream_name, events, opts)
  end

  @doc """
  Appends events to a stream on a specific EventStore instance.
  """
  @spec append_to_stream(GenServer.server(), stream_name(), [event()], keyword()) ::
          {:ok, %{next_expected_version: version()}}
  def append_to_stream(server, stream_name, events, opts) do
    validate_stream_name!(stream_name)
    expected_version = Keyword.get(opts, :expected_version)
    GenServer.call(server, {:append_to_stream, stream_name, events, expected_version})
  end

  @doc """
  Reads events from a stream.

  ## Options

    * `:from` - Starting position (0-indexed). Defaults to 0.
    * `:to` - Ending position (exclusive). Defaults to end of stream.
    * `:max_count` - Maximum number of events to return. Takes precedence over `:to`.

  ## Returns

    * `{:ok, %{events: [event()], version: version()}}` - The events and current stream version
    * `{:ok, %{events: [], version: 0}}` - If stream doesn't exist

  """
  @spec read_stream(stream_name(), keyword()) :: {:ok, %{events: [event()], version: version()}}
  def read_stream(stream_name, opts \\ []) do
    read_stream(__MODULE__, stream_name, opts)
  end

  @doc """
  Reads events from a stream on a specific EventStore instance.
  """
  @spec read_stream(GenServer.server(), stream_name(), keyword()) ::
          {:ok, %{events: [event()], version: version()}}
  def read_stream(server, stream_name, opts) do
    validate_stream_name!(stream_name)
    from = Keyword.get(opts, :from, 0)
    to = Keyword.get(opts, :to)
    max_count = Keyword.get(opts, :max_count)

    validate_pagination_params!(from, to, max_count)
    GenServer.call(server, {:read_stream, stream_name, from, to, max_count})
  end

  @doc """
  Reconstructs aggregate state by applying an evolve function to stream events.

  ## Parameters

    * `stream_name` - The name of the stream
    * `initial_state` - The starting state before applying any events
    * `evolve_fun` - A function `(state, event) -> new_state`
    * `opts` - Same pagination options as `read_stream/2`

  ## Returns

    * `{:ok, %{state: state, version: version}}` - The final state and stream version

  """
  @spec aggregate_stream(stream_name(), term(), (term(), event() -> term()), keyword()) ::
          {:ok, %{state: term(), version: version()}}
  def aggregate_stream(stream_name, initial_state, evolve_fun, opts \\ []) do
    aggregate_stream(__MODULE__, stream_name, initial_state, evolve_fun, opts)
  end

  @doc """
  Reconstructs aggregate state on a specific EventStore instance.
  """
  @spec aggregate_stream(
          GenServer.server(),
          stream_name(),
          term(),
          (term(), event() -> term()),
          keyword()
        ) ::
          {:ok, %{state: term(), version: version()}}
  def aggregate_stream(server, stream_name, initial_state, evolve_fun, opts) do
    {:ok, %{events: events, version: version}} = read_stream(server, stream_name, opts)
    # Wrap evolve_fun to match Enum.reduce's (element, acc) signature
    # while accepting the more natural (state, event) -> state signature
    state = Enum.reduce(events, initial_state, fn event, acc -> evolve_fun.(acc, event) end)
    {:ok, %{state: state, version: version}}
  end

  @doc """
  Subscribes to a stream to receive notifications when events are appended.

  The callback is immediately invoked with the current stream state (if any events exist),
  and will be invoked synchronously on each subsequent append.

  ## Callback Signature

      callback :: (version :: non_neg_integer(), events :: [term()]) -> any()

  ## Returns

    * `{:ok, callback_ref}` - The callback reference for later unsubscription

  """
  @spec subscribe(stream_name(), subscription_callback()) :: {:ok, subscription_callback()}
  def subscribe(stream_name, callback) do
    subscribe(__MODULE__, stream_name, callback)
  end

  @doc """
  Subscribes to a stream on a specific EventStore instance.
  """
  @spec subscribe(GenServer.server(), stream_name(), subscription_callback()) ::
          {:ok, subscription_callback()}
  def subscribe(server, stream_name, callback) do
    validate_stream_name!(stream_name)
    GenServer.call(server, {:subscribe, stream_name, callback})
  end

  @doc """
  Unsubscribes a callback from a stream.

  ## Returns

    * `:ok` - Always succeeds (idempotent)

  """
  @spec unsubscribe(stream_name(), subscription_callback()) :: :ok
  def unsubscribe(stream_name, callback) do
    unsubscribe(__MODULE__, stream_name, callback)
  end

  @doc """
  Unsubscribes a callback from a stream on a specific EventStore instance.
  """
  @spec unsubscribe(GenServer.server(), stream_name(), subscription_callback()) :: :ok
  def unsubscribe(server, stream_name, callback) do
    GenServer.call(server, {:unsubscribe, stream_name, callback})
  end

  @doc """
  Returns a map of all streams and their event counts for debugging.
  """
  @spec debug_all_streams() :: %{stream_name() => non_neg_integer()}
  def debug_all_streams do
    debug_all_streams(__MODULE__)
  end

  @doc """
  Returns a map of all streams on a specific EventStore instance.
  """
  @spec debug_all_streams(GenServer.server()) :: %{stream_name() => non_neg_integer()}
  def debug_all_streams(server) do
    GenServer.call(server, :debug_all_streams)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    state = %{
      streams: %{},
      subscriptions: %{},
      global_position: 0
    }

    Logger.debug("EventStore started")
    {:ok, state}
  end

  @impl true
  def handle_call({:append_to_stream, stream_name, events, expected_version}, _from, state) do
    stream = Map.get(state.streams, stream_name, %{events: [], version: 0})
    current_version = stream.version

    case validate_expected_version(stream_name, current_version, expected_version) do
      :ok ->
        {new_state, new_version} = do_append(state, stream_name, stream, events)

        Logger.debug(
          "Appended #{length(events)} event(s) to stream '#{stream_name}', version: #{current_version} -> #{new_version}"
        )

        {:reply, {:ok, %{next_expected_version: new_version}}, new_state}

      {:error, error} ->
        {:reply, {:error, error}, state}
    end
  end

  @impl true
  def handle_call({:read_stream, stream_name, from, to, max_count}, _from, state) do
    stream = Map.get(state.streams, stream_name, %{events: [], version: 0})
    events = extract_events(stream.events, from, to, max_count)
    {:reply, {:ok, %{events: events, version: stream.version}}, state}
  end

  @impl true
  def handle_call({:subscribe, stream_name, callback}, _from, state) do
    # Add callback to subscriptions
    stream_subs = Map.get(state.subscriptions, stream_name, [])
    new_subs = Map.put(state.subscriptions, stream_name, [callback | stream_subs])
    new_state = %{state | subscriptions: new_subs}

    # Immediately invoke with current state
    stream = Map.get(state.streams, stream_name, %{events: [], version: 0})

    if stream.version > 0 do
      events = Enum.map(stream.events, & &1.event)
      safe_invoke_callback(callback, stream.version, events, stream_name)
    end

    Logger.debug(
      "Subscription added to stream '#{stream_name}', total: #{length(stream_subs) + 1}"
    )

    {:reply, {:ok, callback}, new_state}
  end

  @impl true
  def handle_call({:unsubscribe, stream_name, callback}, _from, state) do
    stream_subs = Map.get(state.subscriptions, stream_name, [])
    new_stream_subs = List.delete(stream_subs, callback)
    new_subs = Map.put(state.subscriptions, stream_name, new_stream_subs)
    new_state = %{state | subscriptions: new_subs}

    Logger.debug(
      "Subscription removed from stream '#{stream_name}', remaining: #{length(new_stream_subs)}"
    )

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:debug_all_streams, _from, state) do
    stream_counts =
      state.streams
      |> Enum.map(fn {name, stream} -> {name, stream.version} end)
      |> Map.new()

    {:reply, stream_counts, state}
  end

  # Private Functions

  defp validate_stream_name!(stream_name)
       when is_binary(stream_name) and byte_size(stream_name) > 0 do
    :ok
  end

  defp validate_stream_name!(_) do
    raise ArgumentError, "stream_name must be a non-empty string"
  end

  defp validate_pagination_params!(from, to, max_count) do
    cond do
      from < 0 ->
        raise ArgumentError, "from must be non-negative, got: #{from}"

      not is_nil(to) and to < from ->
        raise ArgumentError, "to must be >= from, got from: #{from}, to: #{to}"

      not is_nil(max_count) and max_count <= 0 ->
        raise ArgumentError, "max_count must be positive, got: #{max_count}"

      true ->
        :ok
    end
  end

  defp validate_expected_version(_stream_name, _current_version, nil), do: :ok

  defp validate_expected_version(_stream_name, current_version, expected_version)
       when current_version == expected_version,
       do: :ok

  defp validate_expected_version(stream_name, current_version, expected_version) do
    Logger.warning(
      "Version mismatch for stream '#{stream_name}': expected #{expected_version}, got #{current_version}"
    )

    {:error,
     VersionMismatchError.exception(
       stream_name: stream_name,
       expected_version: expected_version,
       current_version: current_version
     )}
  end

  defp do_append(state, _stream_name, stream, []) do
    # No-op for empty events list
    {state, stream.version}
  end

  defp do_append(state, stream_name, stream, events) do
    {envelopes, new_global_position} =
      events
      |> Enum.with_index(stream.version + 1)
      |> Enum.map_reduce(state.global_position, fn {event, stream_pos}, global_pos ->
        new_global_pos = global_pos + 1

        envelope = %EventEnvelope{
          event: event,
          metadata: %EventMetadata{
            event_id: generate_event_id(),
            stream_position: stream_pos,
            log_position: new_global_pos
          }
        }

        {envelope, new_global_pos}
      end)

    new_stream = %{
      events: stream.events ++ envelopes,
      version: stream.version + length(events)
    }

    new_state = %{
      state
      | streams: Map.put(state.streams, stream_name, new_stream),
        global_position: new_global_position
    }

    # Notify subscriptions
    notify_subscriptions(new_state, stream_name, new_stream.version, events)

    {new_state, new_stream.version}
  end

  defp extract_events(envelopes, from, to, max_count) do
    count =
      cond do
        not is_nil(max_count) -> max_count
        not is_nil(to) -> to - from
        true -> length(envelopes)
      end

    envelopes
    |> Enum.slice(from, count)
    |> Enum.map(& &1.event)
  end

  defp notify_subscriptions(state, stream_name, version, events) do
    callbacks = Map.get(state.subscriptions, stream_name, [])

    Enum.each(callbacks, fn callback ->
      safe_invoke_callback(callback, version, events, stream_name)
    end)
  end

  defp safe_invoke_callback(callback, version, events, stream_name) do
    callback.(version, events)
  rescue
    error ->
      Logger.error("Subscription callback error for stream '#{stream_name}': #{inspect(error)}")
  end

  defp generate_event_id do
    <<u0::48, _::4, u1::12, _::2, u2::62>> = :crypto.strong_rand_bytes(16)

    <<u0::48, 4::4, u1::12, 2::2, u2::62>>
    |> Base.encode16(case: :lower)
    |> format_uuid()
  end

  defp format_uuid(
         <<a::binary-size(8), b::binary-size(4), c::binary-size(4), d::binary-size(4),
           e::binary-size(12)>>
       ) do
    "#{a}-#{b}-#{c}-#{d}-#{e}"
  end
end
