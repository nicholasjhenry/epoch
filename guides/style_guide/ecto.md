# 3. Ecto / Data Layer

### 3.1 Schema Design

**PREFER** explicit primary keys over defaults when using UUIDs.

```elixir
# Good
@primary_key {:id, :binary_id, autogenerate: true}
@foreign_key_type :binary_id
schema "users" do
  field :email, :string
  timestamps()
end

# Avoid (implicit integer primary key with UUID foreign keys causes mismatches)
```

**Rationale:** Explicit configuration prevents type mismatches between primary keys and foreign keys.

---

**MUST** use `timestamps()` for auditing.

```elixir
# Good
schema "orders" do
  field :total, :decimal
  timestamps()  # inserted_at, updated_at
end

# Wrong (no audit trail)
schema "orders" do
  field :total, :decimal
end
```

**Rationale:** Timestamps provide essential audit trails. You'll always wish you had them.

---

**PREFER** embedded schemas for value objects without persistence.

```elixir
# Good
defmodule Address do
  use Ecto.Schema

  @primary_key false
  embedded_schema do
    field :street, :string
    field :city, :string
    field :postal_code, :string
  end
end

# In parent schema
schema "users" do
  embeds_one :address, Address
end
```

**Rationale:** Embedded schemas model value objects (no independent lifecycle) without separate tables.

---

### 3.2 Changesets

**MUST** use changesets for all data validation and transformation.

```elixir
# Good
def changeset(user, attrs) do
  user
  |> cast(attrs, [:email, :name, :age])
  |> validate_required([:email, :name])
  |> validate_format(:email, ~r/@/)
  |> validate_number(:age, greater_than: 0)
  |> unique_constraint(:email)
end

# Wrong (direct struct updates skip validation)
struct(user, attrs)
```

**Rationale:** Changesets provide validation, transformation, and error tracking. Bypassing them invites data corruption.

---

**PREFER** separate changesets for different operations.

```elixir
# Good
def registration_changeset(user, attrs) do
  user
  |> cast(attrs, [:email, :password, :name])
  |> validate_required([:email, :password])
  |> hash_password()
end

def update_profile_changeset(user, attrs) do
  user
  |> cast(attrs, [:name, :bio])
  |> validate_required([:name])
end

# Avoid (single changeset trying to handle all cases)
def changeset(user, attrs, operation) do
  # Complex conditional logic...
end
```

**Rationale:** Different operations have different requirements. Separate changesets keep validation logic clear and focused.

---

**PREFER** custom validations as private functions.

```elixir
def changeset(user, attrs) do
  user
  |> cast(attrs, [:email])
  |> validate_corporate_email()
end

defp validate_corporate_email(changeset) do
  validate_change(changeset, :email, fn :email, email ->
    if String.ends_with?(email, "@company.com") do
      []
    else
      [email: "must be a corporate email"]
    end
  end)
end
```

**Rationale:** Custom validations encapsulate complex logic, keeping changeset pipelines readable.

---

### 3.3 Queries

**PREFER** named query functions over inline `Repo` calls.

```elixir
# Good
defmodule Accounts do
  def list_active_users do
    User
    |> where([u], u.status == :active)
    |> order_by([u], desc: u.inserted_at)
    |> Repo.all()
  end
end

# Avoid (in controllers or elsewhere)
Repo.all(from u in User, where: u.status == :active)
```

**Rationale:** Named queries centralize data access, are testable, and provide a clear API.

---

**MUST** use `Repo.preload/2` for associations, never n+1 queries.

```elixir
# Good
def list_posts_with_authors do
  Post
  |> preload(:author)
  |> Repo.all()
end

# Wrong (n+1 query)
def list_posts_with_authors do
  posts = Repo.all(Post)
  Enum.map(posts, fn post ->
    %{post | author: Repo.get(User, post.author_id)}
  end)
end
```

**Rationale:** N+1 queries destroy performance. Always preload associations.

---

**PREFER** composable query functions.

```elixir
# Good
def base_query, do: from(u in User)

def active(query) do
  from u in query, where: u.status == :active
end

def with_orders(query) do
  from u in query, preload: [:orders]
end

# Compose
User
|> base_query()
|> active()
|> with_orders()
|> Repo.all()
```

**Rationale:** Composable queries are reusable, testable, and expressive—build complex queries from simple parts.

---

### 3.4 Migrations

**MUST** make migrations reversible.

```elixir
# Good
def change do
  create table(:users) do
    add :email, :string, null: false
    timestamps()
  end

  create unique_index(:users, [:email])
end

# Wrong (can't rollback)
def up do
  execute "CREATE TABLE users ..."
end

def down, do: :ok  # Can't undo!
```

**Rationale:** Reversible migrations allow safe rollbacks. Irreversible migrations block deployments.

---

**PREFER** `change/0` over `up/0` and `down/0`.

**Rationale:** Ecto automatically generates `down` from `change`—less code, fewer bugs.

---

**MUST** use transactions for multi-statement migrations.

```elixir
# Good
def change do
  alter table(:users) do
    add :status, :string
  end

  execute "UPDATE users SET status = 'active'"

  alter table(:users) do
    modify :status, :string, null: false
  end
end
```

**Rationale:** Migrations run in transactions by default (except for concurrent indexes). Data modifications should always be transactional.

---

### 3.5 Repo Patterns

**PREFER** `Repo.transaction/1` for multi-step operations.

```elixir
# Good
def transfer_money(from_account, to_account, amount) do
  Repo.transaction(fn ->
    with {:ok, _} <- debit_account(from_account, amount),
         {:ok, _} <- credit_account(to_account, amount) do
      :ok
    else
      {:error, reason} -> Repo.rollback(reason)
    end
  end)
end
```

**Rationale:** Transactions ensure atomicity—all operations succeed or none do.

---

**PREFER** `Repo.insert_all/2` for bulk inserts.

```elixir
# Good
timestamps = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
entries = Enum.map(items, &%{name: &1, inserted_at: timestamps, updated_at: timestamps})
Repo.insert_all(Item, entries)

# Avoid (slow)
Enum.each(items, fn item ->
  %Item{name: item} |> Repo.insert()
end)
```

**Rationale:** `insert_all` is orders of magnitude faster than individual inserts.

---
