# 4. OTP / Concurrency

### 4.1 GenServers

**PREFER** GenServers for state management, not computation.

```elixir
# Good (stateful cache)
defmodule Cache do
  use GenServer

  def start_link(_), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  def get(key), do: GenServer.call(__MODULE__, {:get, key})
  def put(key, value), do: GenServer.cast(__MODULE__, {:put, key, value})

  def handle_call({:get, key}, _from, state) do
    {:reply, Map.get(state, key), state}
  end

  def handle_cast({:put, key, value}, state) do
    {:noreply, Map.put(state, key, value)}
  end
end

# Avoid (GenServer doing computation)
def handle_call({:calculate_tax, amount}, _from, state) do
  result = expensive_calculation(amount)  # Blocks other requests!
  {:reply, result, state}
end
```

**Rationale:** GenServers serialize requests. Long-running computations block the mailbox. Use Tasks for computation.

---

**PREFER** `handle_cast` for fire-and-forget, `handle_call` for replies.

**Rationale:** `call` blocks caller until response. `cast` returns immediately. Choose based on whether caller needs response.

---

**MUST** use `handle_continue` for initialization work after `init`.

```elixir
# Good
def init(args) do
  {:ok, initial_state(), {:continue, :load_data}}
end

def handle_continue(:load_data, state) do
  data = load_expensive_data()
  {:noreply, %{state | data: data}}
end

# Avoid (blocks supervisor during init)
def init(args) do
  data = load_expensive_data()  # Blocks!
  {:ok, %{data: data}}
end
```

**Rationale:** Long `init` blocks supervisor startup. `handle_continue` moves work after process is registered.

---

### 4.2 Supervisors

**MUST** use supervision trees for fault tolerance.

```elixir
# Good
defmodule MyApp.Application do
  use Application

  def start(_type, _args) do
    children = [
      MyApp.Repo,
      MyAppWeb.Endpoint,
      {MyApp.Cache, []},
      {Task.Supervisor, name: MyApp.TaskSupervisor}
    ]

    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

**Rationale:** Supervisors automatically restart crashed processes—"let it crash" philosophy.

---

**PREFER** `:one_for_one` strategy by default.

```elixir
# Good default
opts = [strategy: :one_for_one]

# Use :one_for_all when children are interdependent
opts = [strategy: :one_for_all]  # If one fails, restart all

# Use :rest_for_one for ordered dependencies
opts = [strategy: :rest_for_one]  # If one fails, restart it and all after it
```

**Rationale:** `:one_for_one` is most common—isolates failures. Use others only when dependencies demand it.

---

### 4.3 Tasks

**PREFER** supervised Tasks for async work.

```elixir
# Good (supervised)
Task.Supervisor.start_child(MyApp.TaskSupervisor, fn ->
  send_notification(user)
end)

# Avoid (unsupervised, crashes go unnoticed)
Task.start(fn -> send_notification(user) end)
```

**Rationale:** Supervised tasks are monitored. Unsupervised tasks die silently—failures invisible.

---

**PREFER** `Task.async/await` for work that must complete before proceeding.

```elixir
# Good
task = Task.async(fn -> fetch_external_api() end)
result = Task.await(task, 5000)  # 5 second timeout
```

**Rationale:** `async/await` provides timeout and error handling. Fire-and-forget doesn't.

---

### 4.4 Agents

**PREFER** Agents for simple state without complex logic.

```elixir
# Good (simple counter)
{:ok, agent} = Agent.start_link(fn -> 0 end)
Agent.update(agent, &(&1 + 1))
Agent.get(agent, & &1)

# Avoid (complex business logic belongs in GenServer)
Agent.update(agent, fn state ->
  # 50 lines of business logic
end)
```

**Rationale:** Agents are lightweight wrappers around state. Complex logic needs GenServer's structure.

---

### 4.5 Process Design

**PREFER** named processes for singletons, dynamic processes for entities.

```elixir
# Good (singleton cache)
GenServer.start_link(Cache, [], name: Cache)

# Good (one process per user session)
GenServer.start_link(Session, user_id: user_id)
```

**Rationale:** Named processes are globally accessible. Dynamic processes are managed by supervisors/registries.

---

**MUST** trap exits for cleanup in long-lived processes.

```elixir
# Good
def init(state) do
  Process.flag(:trap_exit, true)
  {:ok, state}
end

def terminate(_reason, state) do
  cleanup_resources(state)
  :ok
end
```

**Rationale:** Trapping exits allows graceful cleanup. Without it, resources leak.

---
