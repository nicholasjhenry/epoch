# 5. Architecture

### 5.1 Context Boundaries

**MUST** organize business logic into bounded contexts.

```elixir
# Good
lib/my_app/
  accounts/
    user.ex
    profile.ex
  billing/
    invoice.ex
    payment.ex
  catalog/
    product.ex
    category.ex
```

**Rationale:** Contexts enforce domain boundaries, prevent coupling, and make codebase navigable.

---

**MUST** use context modules as public API; keep schemas private.

```elixir
# Good (public context API)
defmodule MyApp.Accounts do
  def register_user(attrs), do: ...
  def get_user!(id), do: ...
end

# Good (private schema)
defmodule MyApp.Accounts.User do
  # Not called directly from outside Accounts context
end

# Wrong (controllers calling schemas directly)
MyApp.Accounts.User.changeset(...)
```

**Rationale:** Context modules encapsulate implementation. Schemas are internal details.

---

**PREFER** cross-context calls through public APIs, never direct schema access.

```elixir
# Good
defmodule MyApp.Orders do
  alias MyApp.Accounts

  def create_order(user_id, items) do
    user = Accounts.get_user!(user_id)  # Through context API
    # create order logic
  end
end

# Wrong (reaching into another context's internals)
defmodule MyApp.Orders do
  alias MyApp.Accounts.User

  def create_order(user_id, items) do
    user = Repo.get!(User, user_id)  # Bypassing Accounts context!
  end
end
```

**Rationale:** Direct schema access creates tight coupling and breaks encapsulation.

---

### 5.2 Module Dependencies

**MUST** avoid circular dependencies between contexts.

```elixir
# Wrong
MyApp.Accounts -> MyApp.Orders -> MyApp.Accounts  # Circular!

# Good (introduce third context or events)
MyApp.Accounts -> MyApp.EventBus
MyApp.Orders -> MyApp.EventBus
```

**Rationale:** Circular dependencies make code untestable and unreadable. Use events or extract shared concepts.

---

**PREFER** dependency injection over global state.

```elixir
# Good
def create_user(attrs, repo \\ MyApp.Repo) do
  repo.insert(User.changeset(%User{}, attrs))
end

# Avoid (harder to test)
def create_user(attrs) do
  MyApp.Repo.insert(User.changeset(%User{}, attrs))
end
```

**Rationale:** Dependency injection enables testing with mock repos and decouples modules.

---

### 5.3 Umbrella Apps

**PREFER** umbrella projects for large systems with independent deployment units.

```elixir
# Structure
my_app_umbrella/
  apps/
    my_app/         # Core domain
    my_app_web/     # Web interface
    my_app_admin/   # Admin interface
    my_app_api/     # Public API
```

**Rationale:** Umbrella apps enforce boundaries, enable independent deployment, and scale team autonomy.

---

**MUST** declare dependencies between umbrella apps explicitly.

```elixir
# In my_app_web/mix.exs
defp deps do
  [
    {:my_app, in_umbrella: true},
    {:phoenix, "~> 1.7"}
  ]
end
```

**Rationale:** Explicit dependencies prevent accidental coupling and document relationships.

---

**PREFER** shared database for umbrella apps unless truly independent systems.

**Rationale:** Separate databases complicate transactions and consistency. Only separate when apps are truly decoupled services.

---

### 5.4 Configuration

**MUST** use runtime configuration for environment-specific values.

```elixir
# Good (config/runtime.exs)
config :my_app, MyApp.Repo,
  url: System.get_env("DATABASE_URL")

# Avoid (config/config.exs - compile time)
config :my_app, MyApp.Repo,
  url: System.get_env("DATABASE_URL")  # Won't work in releases!
```

**Rationale:** Runtime config works in releases. Compile-time config bakes values at build time.

---

**PREFER** environment variables over hard-coded values.

```elixir
# Good
database_url = System.get_env("DATABASE_URL") || raise "DATABASE_URL not set"

# Wrong
database_url = "postgresql://user:pass@localhost/db"
```

**Rationale:** Environment variables enable 12-factor deployments. Hard-coded values are brittle and insecure.

---

### 5.5 Error Handling

**PREFER** explicit error tuples over exceptions for expected failures.

```elixir
# Good (expected failure)
def fetch_user(id) do
  case Repo.get(User, id) do
    nil -> {:error, :not_found}
    user -> {:ok, user}
  end
end

# Avoid (exceptions for control flow)
def fetch_user(id) do
  Repo.get(User, id) || raise "User not found"
end
```

**Rationale:** Error tuples make failure explicit and force callers to handle errors. Exceptions are for unexpected failures.

---

**MUST** let supervisors handle unexpected crashes; don't catch everything.

```elixir
# Good (let it crash for unexpected errors)
def process_payment(invoice) do
  # If this crashes, supervisor restarts
  PaymentGateway.charge!(invoice)
end

# Avoid (hiding bugs)
def process_payment(invoice) do
  try do
    PaymentGateway.charge!(invoice)
  rescue
    _ -> {:error, :unknown}  # What failed? How to fix?
  end
end
```

**Rationale:** "Let it crash" exposes bugs. Catching everything hides them. Use supervisors for recovery.

---

**PREFER** `with` to propagate errors up the stack.

```elixir
# Good
def register_and_notify(attrs) do
  with {:ok, user} <- Accounts.register_user(attrs),
       {:ok, _} <- Mailer.send_welcome(user) do
    {:ok, user}
  end
end

# Errors automatically propagate
```

**Rationale:** `with` creates a clean error path without manual error handling at every step.

---
