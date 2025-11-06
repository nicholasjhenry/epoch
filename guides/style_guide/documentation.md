# 7. Documentation

**MUST** document all public modules and functions.

```elixir
defmodule MyApp.Accounts do
  @moduledoc """
  The Accounts context handles user registration, authentication, and profile management.
  """

  @doc """
  Registers a new user with the given attributes.

  ## Examples

      iex> register_user(%{email: "user@example.com", password: "secret"})
      {:ok, %User{}}

      iex> register_user(%{email: "invalid"})
      {:error, %Ecto.Changeset{}}
  """
  def register_user(attrs), do: ...
end
```

**Rationale:** Documentation makes code self-explanatory. Future you (and teammates) will thank you.

---

**PREFER** doctests for simple examples.

```elixir
@doc """
## Examples

    iex> double(2)
    4

    iex> double(0)
    0
"""
def double(n), do: n * 2
```

**Rationale:** Doctests are executable documentation—they verify examples stay accurate.

---

**PREFER** `@typedoc` and `@type` for public types.

```elixir
@typedoc """
Represents the possible states of an order.
"""
@type order_status :: :pending | :processing | :shipped | :delivered | :cancelled
```

**Rationale:** Type documentation makes APIs self-documenting and aids Dialyzer analysis.

---

**PREFER** README files for umbrella app and project root.

**Rationale:** READMEs provide project overview, setup instructions, and architecture notes—first stop for new developers.

---

**PREFER** Use domain-specific type aliases in function specs instead of their underlying implementation types.

```elixir
# Good
@spec get_team(Team.id()) :: {:ok, Team.t()} | {:error, :not_found}
def get_team(team_id), do: Repo.get(Team, team_id)

@spec create_team_member(Team.id(), User.id(), String.t()) :: {:ok, TeamMember.t()} | {:error, Ecto.Changeset.t(TeamMember.t())}
def create_team_member(team_id, user_id, role), do: ...

# Avoid
@spec get_team(Ecto.UUID.t()) :: {:ok, Team.t()} | {:error, :not_found}
def get_team(team_id), do: Repo.get(Team, team_id)

@spec create_team_member(Ecto.UUID.t(), Ecto.UUID.t(), String.t()) :: {:ok, TeamMember.t()} | {:error, Ecto.Changeset.t()}
def create_team_member(team_id, user_id, role), do: ...
```

**Rationale:** Domain types communicate semantic meaning and intent, making specs self-documenting. When you later change `Team.id()` from UUID to integer, only one type definition needs updating instead of dozens of function specs.

---
