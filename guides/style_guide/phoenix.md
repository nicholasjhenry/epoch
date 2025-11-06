# 2. Phoenix / Web Layer

### 2.1 Controllers

**MUST** keep controllers thin—delegate to contexts immediately.

```elixir
# Good
defmodule MyAppWeb.UserController do
  def create(conn, %{"user" => user_params}) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "User created successfully.")
        |> redirect(to: ~p"/users/#{user}")

      {:error, changeset} ->
        render(conn, :new, changeset: changeset)
    end
  end
end

# Avoid (business logic in controller)
defmodule MyAppWeb.UserController do
  def create(conn, %{"user" => user_params}) do
    changeset = User.changeset(%User{}, user_params)

    if changeset.valid? do
      case Repo.insert(changeset) do
        {:ok, user} ->
          Mailer.send_welcome_email(user)
          # ...
      end
    end
  end
end
```

**Rationale:** Controllers handle HTTP concerns. Business logic belongs in contexts, not controllers.

---

**PREFER** pattern matching action parameters for clarity.

```elixir
# Good
def show(conn, %{"id" => id}) do
  user = Accounts.get_user!(id)
  render(conn, :show, user: user)
end

# Avoid
def show(conn, params) do
  user = Accounts.get_user!(params["id"])
  render(conn, :show, user: user)
end
```

**Rationale:** Destructuring documents expected parameters and fails fast on structure mismatch.

---

**PREFER** action fallback for consistent error handling.

```elixir
# In controller
defmodule MyAppWeb.UserController do
  use MyAppWeb, :controller

  action_fallback MyAppWeb.FallbackController

  def show(conn, %{"id" => id}) do
    with {:ok, user} <- Accounts.fetch_user(id) do
      render(conn, :show, user: user)
    end
  end
end

# Fallback controller
defmodule MyAppWeb.FallbackController do
  use Phoenix.Controller

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(MyAppWeb.ErrorView)
    |> render(:"404")
  end
end
```

**Rationale:** Centralized error handling eliminates repetitive boilerplate and ensures consistent responses.

---

### 2.2 Views and Components

**PREFER** function components over template files for reusable UI.

```elixir
# Good (function component)
defmodule MyAppWeb.Components.Card do
  use Phoenix.Component

  attr :title, :string, required: true
  attr :body, :string, required: true
  slot :actions

  def card(assigns) do
    ~H"""
    <div class="card">
      <h3><%= @title %></h3>
      <p><%= @body %></p>
      <div class="actions">
        <%= render_slot(@actions) %>
      </div>
    </div>
    """
  end
end

# Avoid (duplicated HTML across templates)
```

**Rationale:** Function components are testable, composable, and eliminate template duplication.

---

**MUST** use `attr` and `slot` declarations for component APIs.

```elixir
# Good
attr :user, User, required: true
attr :show_email, :boolean, default: false
slot :actions, required: false

# Wrong (undocumented component API)
def user_card(assigns) do
  ~H"""
  <div><%= @user.name %></div>
  """
end
```

**Rationale:** Declarations provide compile-time documentation and validation—self-documenting components.

---

### 2.3 LiveView

**PREFER** stateful LiveView for interactive UI; traditional controllers for simple CRUD.

**Rationale:** LiveView shines with real-time interactivity. Don't use it for basic forms—unnecessary overhead.

---

**MUST** initialize socket assigns in `mount/3`.

```elixir
# Good
def mount(_params, _session, socket) do
  {:ok,
   socket
   |> assign(:users, [])
   |> assign(:loading, true)}
end

# Wrong (accessing undefined assigns)
def mount(_params, _session, socket) do
  {:ok, socket}
end

def handle_event("load", _, socket) do
  # socket.assigns.users doesn't exist yet!
end
```

**Rationale:** Uninitialized assigns cause runtime errors. Mount is the contract for initial state.

---

**PREFER** `handle_event` for user actions, `handle_info` for async messages.

```elixir
# Good (user clicked button)
def handle_event("delete_user", %{"id" => id}, socket) do
  Accounts.delete_user(id)
  {:noreply, socket}
end

# Good (async task completed)
def handle_info({:user_deleted, user_id}, socket) do
  {:noreply, update(socket, :users, &List.delete(&1, user_id))}
end
```

**Rationale:** Separation of concerns. Events = user input. Info = system messages/async results.

---

**PREFER** temporary assigns for large lists.

```elixir
def mount(_params, _session, socket) do
  {:ok,
   socket
   |> assign(:items, [])
   |> stream(:messages, []), temporary_assigns: [items: []]}
end
```

**Rationale:** Large lists kept in assigns consume memory. Temporary assigns + streams optimize LiveView performance.

---

### 2.4 Channels and PubSub

**PREFER** Phoenix.PubSub for broadcasting within app; channels for client communication.

```elixir
# Broadcasting to subscribers (server-side)
Phoenix.PubSub.broadcast(MyApp.PubSub, "orders:#{order_id}", {:order_updated, order})

# Channel receives and pushes to clients
def handle_info({:order_updated, order}, socket) do
  push(socket, "order_updated", %{order: order})
  {:noreply, socket}
end
```

**Rationale:** PubSub is for internal pub/sub. Channels are the bridge to clients.

---

**MUST** validate channel joins with authentication.

```elixir
# Good
def join("room:" <> room_id, _payload, socket) do
  if authorized?(socket.assigns.user, room_id) do
    {:ok, socket}
  else
    {:error, %{reason: "unauthorized"}}
  end
end

# Wrong (no authorization)
def join("room:" <> _room_id, _payload, socket) do
  {:ok, socket}
end
```

**Rationale:** Channels are externally accessible. Authorization prevents unauthorized access.

---

### 2.5 Plugs

**PREFER** custom plugs for cross-cutting concerns.

```elixir
# Good
defmodule MyAppWeb.Plugs.RequireAuth do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_status(:unauthorized)
      |> Phoenix.Controller.redirect(to: "/login")
      |> halt()
    end
  end
end

# In router
pipeline :authenticated do
  plug MyAppWeb.Plugs.RequireAuth
end
```

**Rationale:** Plugs centralize logic like auth, logging, rate-limiting—keeping controllers focused.

---

**MUST** call `halt/1` when plug should stop pipeline.

```elixir
# Good (stops pipeline after redirect)
conn
|> redirect(to: "/login")
|> halt()

# Wrong (pipeline continues, may cause errors)
redirect(conn, to: "/login")
```

**Rationale:** Without `halt/1`, downstream plugs execute, causing unexpected behavior.

---
