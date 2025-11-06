# 1. Code Style

### 1.1 Naming Conventions

#### Modules

**PREFER** noun-based names that represent domain concepts, not actions.

```elixir
# Good
defmodule Order
defmodule PaymentProcessor
defmodule UserRegistration

# Avoid
defmodule ProcessPayments
defmodule RegisterUser
```

**Rationale:** Modules represent boundaries and concepts, not procedures. Noun-based names make the domain model clearer and align with how humans conceptualize systems.

---

**MUST** use nested modules to express hierarchy, not underscores.

```elixir
# Good
defmodule MyApp.Accounts.User
defmodule MyApp.Billing.Invoice

# Wrong
defmodule MyApp.Accounts_User
```

**Rationale:** Elixir's module system is hierarchical. Underscores break tooling expectations (documentation, code navigation) and obscure relationships.

---

#### Functions

**PREFER** verb-based names for public functions that perform actions.

```elixir
# Good
def charge_customer(invoice, payment_method)
def calculate_tax(amount, jurisdiction)
def validate_email(email)

# Avoid
def customer_charge(invoice, payment_method)
def tax(amount, jurisdiction)
```

**Rationale:** Functions are verbs—they do things. Verb-first naming makes intent immediately clear at call sites.

---

**PREFER** predicate functions end with `?` and return booleans.

```elixir
# Good
def active?(user), do: user.status == :active
def expired?(token), do: DateTime.compare(token.expires_at, DateTime.utc_now()) == :lt

# Avoid
def is_active(user)  # Good but less idiomatic
def check_expired(token)  # Unclear return type
```

**Rationale:** The `?` suffix is a universal Elixir convention signaling boolean returns, reducing cognitive load.

---

**MUST** use `!` suffix only for functions that raise on error.

```elixir
# Good
def fetch_user!(id), do: Repo.get!(User, id)
def parse_json!(string), do: Jason.decode!(string)

# Wrong
def important_function!()  # Doesn't raise
def validate_data!(changeset)  # Returns {:ok, _} or {:error, _}
```

**Rationale:** The `!` suffix is a contract: "this will raise." Breaking this contract creates confusion and bugs.

---

#### Variables

**PREFER** descriptive names over abbreviations.

```elixir
# Good
user_changeset = User.changeset(user, attrs)
payment_result = PaymentGateway.charge(customer, amount)

# Avoid
cs = User.changeset(user, attrs)
pr = PaymentGateway.charge(customer, amount)
```

**Rationale:** Elixir isn't character-limited. Clarity trumps brevity. Future maintainers (including you) will thank you.

---

**PREFER** `_` prefix for unused variables in pattern matches.

```elixir
# Good
def handle_event("delete", _params, socket)
{:ok, _result} = perform_action()

# Avoid
def handle_event("delete", params, socket)  # Compiler warning
{:ok, result} = perform_action()  # Unused variable
```

**Rationale:** Signals intent and eliminates compiler warnings. The `_` says "I know this exists, I'm ignoring it deliberately."

---

### 1.2 Module Organization

**MUST** order module contents as: moduledoc, use/import/alias/require, module attributes, type specs, public functions, private functions.

```elixir
defmodule MyApp.Accounts.User do
  @moduledoc """
  Represents a user in the system.
  """

  use Ecto.Schema
  import Ecto.Changeset
  alias MyApp.Accounts.Profile

  @primary_key {:id, :binary_id, autogenerate: true}
  @derive {Jason.Encoder, only: [:id, :email, :name]}

  @type t :: %__MODULE__{
    id: Ecto.UUID.t(),
    email: String.t(),
    name: String.t()
  }

  # Public functions
  def changeset(user, attrs), do: ...

  # Private functions
  defp validate_email_format(changeset), do: ...
end
```

**Rationale:** Consistent ordering makes modules scannable. Documentation and dependencies appear first; implementation details come last.

---

**PREFER** grouping related functions with blank lines and comments.

```elixir
defmodule Order do
  # Lifecycle functions
  def create(attrs), do: ...
  def update(order, attrs), do: ...
  def cancel(order), do: ...

  # Query functions
  def list_pending(), do: ...
  def get_by_number(number), do: ...

  # Private helpers
  defp calculate_total(order), do: ...
  defp apply_discount(amount, code), do: ...
end
```

**Rationale:** Logical grouping reduces cognitive load. Readers can quickly locate related functionality.

---

**MUST** limit module size to ~300 lines; refactor into submodules beyond that.

**Rationale:** Large modules violate Single Responsibility Principle. If a module is doing too much, it's hiding multiple concepts that should be separated.

---

### 1.3 Function Design

**PREFER** functions with 1-4 parameters; reconsider design beyond 4.

```elixir
# Good
def create_invoice(customer, line_items, opts \\ [])

# Reconsider
def create_invoice(customer, line_items, tax_rate, discount_code, payment_terms, notes, metadata)

# Better: use a struct or keyword list
def create_invoice(customer, line_items, %InvoiceOptions{} = options)
```

**Rationale:** High arity signals missing abstraction. Data clumps belong in structs or maps.

---

**PREFER** explicit returns over implicit ones for complex functions.

```elixir
# Good (explicit intent)
def process_payment(invoice) do
  with {:ok, charge} <- charge_customer(invoice),
       {:ok, receipt} <- generate_receipt(charge) do
    {:ok, receipt}
  else
    {:error, reason} -> {:error, reason}
  end
end

# Acceptable for trivial functions
def double(n), do: n * 2
```

**Rationale:** Explicit returns clarify intent in multi-clause functions. Implicit returns work well for one-liners.

---

**MUST** use multi-clause functions for domain-driven branching.

```elixir
# Good
def calculate_shipping(:express, weight), do: weight * 10
def calculate_shipping(:standard, weight), do: weight * 5
def calculate_shipping(:free, _weight), do: 0

# Avoid
def calculate_shipping(type, weight) do
  case type do
    :express -> weight * 10
    :standard -> weight * 5
    :free -> 0
  end
end
```

**Rationale:** Multi-clause functions are pattern matching at its finest—readable, extensible, and efficient.

---

**PREFER** private functions for logic that doesn't need external exposure.

```elixir
# Public API
def register_user(attrs) do
  attrs
  |> validate_registration()
  |> create_user()
  |> send_welcome_email()
end

# Private helpers
defp validate_registration(attrs), do: ...
defp create_user(attrs), do: ...
defp send_welcome_email(user), do: ...
```

**Rationale:** Private functions document internal implementation without polluting the public API.

---

### 1.4 Pattern Matching

**MUST** pattern match in function heads instead of extracting in body.

```elixir
# Good
def render(%{status: :active} = user) do
  # work with active user
end

def render(%{status: :inactive} = user) do
  # work with inactive user
end

# Avoid
def render(user) do
  case user.status do
    :active -> ...
    :inactive -> ...
  end
end
```

**Rationale:** Pattern matching in heads is declarative and leverages Elixir's dispatch mechanism—cleaner and faster.

---

**PREFER** destructuring in function parameters over accessing fields.

```elixir
# Good
def format_name(%{first_name: first, last_name: last}) do
  "#{first} #{last}"
end

# Avoid
def format_name(user) do
  "#{user.first_name} #{user.last_name}"
end
```

**Rationale:** Destructuring documents what data is actually used and fails fast if structure doesn't match.

---

**PREFER** pin operator `^` for matching against existing variables.

```elixir
# Good
status = :pending
case order do
  %Order{status: ^status} -> :matched
  _ -> :not_matched
end

# Avoid (rebinds status)
case order do
  %Order{status: status} -> :matched  # Creates new binding!
end
```

**Rationale:** The pin operator prevents accidental rebinding and makes intent explicit.

---

### 1.5 Guards and Conditionals

**PREFER** guards for type/structure validation in function heads.

```elixir
# Good
def calculate_discount(amount) when is_number(amount) and amount > 0 do
  amount * 0.1
end

def calculate_discount(_), do: {:error, :invalid_amount}

# Avoid
def calculate_discount(amount) do
  if is_number(amount) and amount > 0 do
    amount * 0.1
  else
    {:error, :invalid_amount}
  end
end
```

**Rationale:** Guards leverage pattern matching dispatch, are more efficient, and communicate preconditions upfront.

---

**PREFER** `case` over nested `if/else`.

```elixir
# Good
case user_type do
  :admin -> grant_full_access()
  :member -> grant_member_access()
  :guest -> grant_guest_access()
end

# Avoid
if user_type == :admin do
  grant_full_access()
else
  if user_type == :member do
    grant_member_access()
  else
    grant_guest_access()
  end
end
```

**Rationale:** `case` is more readable and idiomatic for multi-way branching.

---

**PREFER** `with` for sequential operations that may fail.

```elixir
# Good
def create_order(user_id, items) do
  with {:ok, user} <- fetch_user(user_id),
       {:ok, validated_items} <- validate_items(items),
       {:ok, order} <- insert_order(user, validated_items) do
    {:ok, order}
  end
end

# Avoid
def create_order(user_id, items) do
  case fetch_user(user_id) do
    {:ok, user} ->
      case validate_items(items) do
        {:ok, validated_items} ->
          insert_order(user, validated_items)
        error -> error
      end
    error -> error
  end
end
```

**Rationale:** `with` creates a linear, readable flow for happy-path logic without nesting hell.

---

### 1.6 Data Structures

**PREFER** structs over maps for domain entities.

```elixir
# Good
defmodule User do
  defstruct [:id, :email, :name, role: :member]
end

%User{id: 1, email: "user@example.com"}

# Avoid for domain entities
%{id: 1, email: "user@example.com", name: nil}
```

**Rationale:** Structs provide compile-time key checking, default values, and clear domain boundaries.

---

**PREFER** maps for dynamic/external data.

```elixir
# Good (JSON from external API)
%{"user_id" => "123", "timestamp" => "2025-01-15"}

# Good (configuration)
config = %{timeout: 5000, retry: 3}
```

**Rationale:** Maps are flexible for unpredictable shapes. Don't force structs onto data you don't control.

---

**MUST** use keyword lists for options/configuration passed to functions.

```elixir
# Good
def fetch_posts(user, opts \\ []) do
  limit = Keyword.get(opts, :limit, 20)
  sort = Keyword.get(opts, :sort, :desc)
  # ...
end

fetch_posts(user, limit: 10, sort: :asc)
```

**Rationale:** Keyword lists allow duplicate keys (order matters) and are idiomatic for function options in Elixir.

---

**PREFER** tuples for fixed-size, heterogeneous collections.

```elixir
# Good
{:ok, user}
{:error, :not_found}
{x, y, z}  # Coordinates

# Avoid
[:ok, user]  # List suggests homogeneous/variable-length
```

**Rationale:** Tuples signal fixed structure. Lists signal iteration.

---

### 1.7 Pipelines

**PREFER** pipelines for transforming data through multiple steps.

```elixir
# Good
user_attrs
|> validate_email()
|> normalize_name()
|> create_user()
|> send_welcome_email()

# Avoid
send_welcome_email(
  create_user(
    normalize_name(
      validate_email(user_attrs)
    )
  )
)
```

**Rationale:** Pipelines read like prose: "take data, do this, then this, then this." Nested calls read inside-out.

---

**MUST** ensure first argument is the data being transformed.

```elixir
# Good
def normalize_name(attrs), do: ...
def validate_email(attrs), do: ...

# Wrong (breaks pipeline)
def normalize_name(opts, attrs), do: ...  # Options shouldn't be first
```

**Rationale:** Pipelines depend on consistent argument ordering. Data-first is the Elixir convention.

---

**PREFER** breaking long pipelines into intermediate variables.

```elixir
# Good
validated_attrs =
  attrs
  |> validate_email()
  |> validate_password()
  |> normalize_phone()

enriched_attrs =
  validated_attrs
  |> add_default_settings()
  |> add_timestamps()

create_user(enriched_attrs)

# Avoid (too long, hard to debug)
attrs
|> validate_email()
|> validate_password()
|> normalize_phone()
|> add_default_settings()
|> add_timestamps()
|> add_metadata()
|> add_audit_log()
|> create_user()
```

**Rationale:** Long pipelines become unreadable. Intermediate variables provide natural checkpoints for debugging and comprehension.

---
