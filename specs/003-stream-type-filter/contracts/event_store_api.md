# EventStore API Contract: Stream Type Filter

**Feature**: 003-stream-type-filter  
**Date**: 2025-11-25

## New Function: read_by_stream_type/3

### Signature

```elixir
@spec read_by_stream_type(String.t(), keyword()) ::
        {:ok, filtered_events_result()} | {:error, term()}

@spec read_by_stream_type(GenServer.server(), String.t(), keyword()) ::
        {:ok, filtered_events_result()} | {:error, term()}
```

### Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| server | GenServer.server() | No | __MODULE__ | EventStore process |
| stream_type | String.t() | Yes | - | Type prefix to filter by |
| opts | keyword() | No | [] | Options (see below) |

### Options

| Option | Type | Default | Range | Description |
|--------|------|---------|-------|-------------|
| :page | pos_integer() | 1 | >= 1 | Page number |
| :page_size | pos_integer() | 20 | 1-100 | Events per page |

### Return Value

```elixir
@type filtered_events_result :: %{
  events: [event_with_stream()],
  has_more: boolean(),
  total: non_neg_integer()
}

@type event_with_stream :: %{
  event: term(),
  stream_name: String.t(),
  metadata: EventMetadata.t()
}
```

### Examples

```elixir
# Basic usage
{:ok, result} = EventStore.read_by_stream_type("order")
# => {:ok, %{events: [...], has_more: true, total: 50}}

# With pagination
{:ok, result} = EventStore.read_by_stream_type("order", page: 2, page_size: 10)
# => {:ok, %{events: [...], has_more: true, total: 50}}

# Empty result
{:ok, result} = EventStore.read_by_stream_type("nonexistent")
# => {:ok, %{events: [], has_more: false, total: 0}}

# Invalid input
{:error, reason} = EventStore.read_by_stream_type("")
# => {:error, "Stream type is required"}

{:error, reason} = EventStore.read_by_stream_type("order", page_size: 200)
# => {:error, "Page size must be between 1 and 100"}
```

### Behavior

1. **Filtering**: Matches streams where `extract_stream_type(stream_name) == stream_type`
2. **Ordering**: Results sorted by `metadata.log_position` (global chronological order)
3. **Pagination**: Applies after filtering and sorting
4. **Empty streams**: Streams with no events are excluded from results

### Error Cases

| Condition | Error |
|-----------|-------|
| Empty stream_type | `{:error, "Stream type is required"}` |
| Whitespace-only stream_type | `{:error, "Stream type is required"}` |
| page < 1 | `{:error, "Page must be at least 1"}` |
| page_size < 1 | `{:error, "Page size must be between 1 and 100"}` |
| page_size > 100 | `{:error, "Page size must be between 1 and 100"}` |

---

## New Helper: extract_stream_type/1

### Signature

```elixir
@spec extract_stream_type(String.t()) :: String.t()
```

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| stream_name | String.t() | Yes | Full stream name |

### Return Value

The stream type prefix (portion before first hyphen).

### Examples

```elixir
extract_stream_type("order-123")     # => "order"
extract_stream_type("order-456-v2")  # => "order"
extract_stream_type("payment")       # => "payment"
extract_stream_type("")              # => ""
```

### Behavior

1. Splits on first hyphen only
2. Returns first segment as type
3. If no hyphen, returns entire string

---

## Modified Function: append_to_stream/4

### Additional Behavior

After successful append, broadcasts to PubSub:

```elixir
Phoenix.PubSub.broadcast(
  Epoch.PubSub,
  "stream_type:#{extract_stream_type(stream_name)}",
  {:events_appended, stream_name, events}
)
```

### Broadcast Message

```elixir
{:events_appended, stream_name, events}
```

| Field | Type | Description |
|-------|------|-------------|
| stream_name | String.t() | The stream that received events |
| events | [term()] | Raw domain events (not envelopes) |

### Subscription

LiveViews subscribe to receive broadcasts:

```elixir
Phoenix.PubSub.subscribe(Epoch.PubSub, "stream_type:order")
```

### Example Flow

```elixir
# 1. Append event
EventStore.append_to_stream("order-123", [%OrderPlaced{id: "123"}])

# 2. Broadcast sent to "stream_type:order"
# {:events_appended, "order-123", [%OrderPlaced{id: "123"}]}

# 3. All subscribers to "stream_type:order" receive message
def handle_info({:events_appended, stream_name, events}, socket) do
  # Update UI
end
```
