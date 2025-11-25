defmodule EpochWeb.Dev.EventsLive do
  @moduledoc """
  LiveView for viewing and filtering events by stream type.

  Accessible at /dev/events in development mode.
  """

  use EpochWeb, :live_view

  alias Epoch.EventStore

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:stream_type, nil)
     |> assign(:page, 1)
     |> assign(:page_size, 20)
     |> assign(:has_more, false)
     |> assign(:total, 0)
     |> assign(:events_empty?, true)
     |> stream_configure(:events, dom_id: &event_dom_id/1)
     |> stream(:events, [])}
  end

  @impl true
  def handle_event("filter", %{"stream_type" => stream_type}, socket) do
    stream_type = String.trim(stream_type)

    if stream_type == "" do
      {:noreply, put_flash(socket, :error, "Stream type is required")}
    else
      # Unsubscribe from old topic if any
      if socket.assigns.stream_type && connected?(socket) do
        Phoenix.PubSub.unsubscribe(Epoch.PubSub, "stream_type:#{socket.assigns.stream_type}")
      end

      # Subscribe to new topic for live updates
      if connected?(socket) do
        Phoenix.PubSub.subscribe(Epoch.PubSub, "stream_type:#{stream_type}")
      end

      case EventStore.read_by_stream_type(stream_type,
             page: 1,
             page_size: socket.assigns.page_size
           ) do
        {:ok, result} ->
          {:noreply,
           socket
           |> assign(:stream_type, stream_type)
           |> assign(:page, 1)
           |> assign(:has_more, result.has_more)
           |> assign(:total, result.total)
           |> assign(:events_empty?, result.events == [])
           |> stream(:events, result.events, reset: true)}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, reason)}
      end
    end
  end

  @impl true
  def handle_event("clear_filter", _params, socket) do
    # Unsubscribe from current topic
    if socket.assigns.stream_type && connected?(socket) do
      Phoenix.PubSub.unsubscribe(Epoch.PubSub, "stream_type:#{socket.assigns.stream_type}")
    end

    {:noreply,
     socket
     |> assign(:stream_type, nil)
     |> assign(:page, 1)
     |> assign(:has_more, false)
     |> assign(:total, 0)
     |> assign(:events_empty?, true)
     |> stream(:events, [], reset: true)}
  end

  @impl true
  def handle_event("next_page", _params, socket) do
    new_page = socket.assigns.page + 1

    case EventStore.read_by_stream_type(socket.assigns.stream_type,
           page: new_page,
           page_size: socket.assigns.page_size
         ) do
      {:ok, result} ->
        {:noreply,
         socket
         |> assign(:page, new_page)
         |> assign(:has_more, result.has_more)
         |> stream(:events, result.events, reset: true)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, reason)}
    end
  end

  @impl true
  def handle_event("prev_page", _params, socket) do
    new_page = max(1, socket.assigns.page - 1)

    case EventStore.read_by_stream_type(socket.assigns.stream_type,
           page: new_page,
           page_size: socket.assigns.page_size
         ) do
      {:ok, result} ->
        {:noreply,
         socket
         |> assign(:page, new_page)
         |> assign(:has_more, result.has_more)
         |> stream(:events, result.events, reset: true)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, reason)}
    end
  end

  @impl true
  def handle_info({:events_appended, stream_name, events}, socket) do
    # Only process if we're on page 1 (showing latest events)
    if socket.assigns.page == 1 do
      # Transform events to event_with_stream format and prepend to stream
      # Events are EventEnvelope structs with :event and :metadata fields
      events_with_stream =
        Enum.map(events, fn envelope ->
          %{
            event: envelope.event,
            stream_name: stream_name,
            metadata: envelope.metadata
          }
        end)

      # Prepend new events (at: 0 puts them at the beginning)
      socket =
        Enum.reduce(events_with_stream, socket, fn event, acc ->
          stream_insert(acc, :events, event, at: 0)
        end)

      {:noreply,
       socket
       |> assign(:total, socket.assigns.total + length(events))
       |> assign(:events_empty?, false)}
    else
      # On other pages, just update the total count
      {:noreply, assign(socket, :total, socket.assigns.total + length(events))}
    end
  end

  # Helper to extract readable event type name from struct
  defp event_type_name(event) when is_struct(event) do
    event.__struct__
    |> Module.split()
    |> List.last()
  end

  defp event_type_name(event) when is_map(event) do
    Map.get(event, :type, "Event")
  end

  defp event_type_name(_event), do: "Event"

  # Generate unique DOM ID for stream items
  defp event_dom_id(%{metadata: %{event_id: id}}), do: "event-#{id}"

  defp event_dom_id(%{metadata: metadata}) when is_struct(metadata) do
    "event-#{metadata.event_id}"
  end

  defp event_dom_id(%{event: event, stream_name: name}) do
    hash = :erlang.phash2({name, event})
    "event-#{hash}"
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6 max-w-6xl mx-auto">
      <h1 class="text-2xl font-bold mb-4">Event Store Viewer</h1>

      <%!-- Filter Form --%>
      <.form for={%{}} id="filter-form" phx-submit="filter" class="mb-6">
        <div class="flex gap-4 items-center">
          <input
            type="text"
            name="stream_type"
            value={@stream_type}
            placeholder="Enter stream type (e.g., order)"
            class="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
          />
          <button
            type="submit"
            class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition"
          >
            Filter
          </button>
          <button
            :if={@stream_type}
            type="button"
            phx-click="clear_filter"
            class="px-4 py-2 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300 transition"
          >
            Clear
          </button>
        </div>
      </.form>

      <%!-- Results Summary --%>
      <div :if={@stream_type} class="mb-4 text-gray-600">
        <p>
          Showing events for type "<strong class="text-gray-900">{@stream_type}</strong>"
          ({@total} total)
        </p>
      </div>

      <%!-- Empty State Message --%>
      <div :if={@events_empty?} class="text-gray-500 text-center py-8">
        <%= if @stream_type do %>
          No events found for type "{@stream_type}"
        <% else %>
          Enter a stream type to view events
        <% end %>
      </div>

      <%!-- Events List --%>
      <div id="events" phx-update="stream" class="space-y-2">
        <div
          :for={{id, event} <- @streams.events}
          id={id}
          class="border rounded-lg p-4 bg-white shadow-sm"
        >
          <div class="flex justify-between items-start mb-2">
            <span class="font-mono text-sm text-blue-600">{event.stream_name}</span>
            <span class="text-gray-400 text-xs">#{event.metadata.log_position}</span>
          </div>
          <div class="text-sm">
            <span class="font-semibold text-gray-800">{event_type_name(event.event)}</span>
            <pre class="mt-2 p-2 bg-gray-50 rounded text-xs overflow-x-auto"><code>{inspect(event.event, pretty: true)}</code></pre>
          </div>
        </div>
      </div>

      <%!-- Pagination --%>
      <div :if={@stream_type && @total > 0} class="mt-6 flex items-center justify-center gap-4">
        <button
          phx-click="prev_page"
          disabled={@page == 1}
          class={[
            "px-4 py-2 rounded-lg transition",
            @page == 1 && "bg-gray-100 text-gray-400 cursor-not-allowed",
            @page != 1 && "bg-gray-200 text-gray-700 hover:bg-gray-300"
          ]}
        >
          Previous
        </button>
        <span class="text-gray-600">Page {@page}</span>
        <button
          phx-click="next_page"
          disabled={!@has_more}
          class={[
            "px-4 py-2 rounded-lg transition",
            !@has_more && "bg-gray-100 text-gray-400 cursor-not-allowed",
            @has_more && "bg-gray-200 text-gray-700 hover:bg-gray-300"
          ]}
        >
          Next
        </button>
      </div>
    </div>
    """
  end
end
