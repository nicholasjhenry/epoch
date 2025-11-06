# 6. Testing

**MUST** test all public context functions.

```elixir
# Good
defmodule MyApp.AccountsTest do
  use MyApp.DataCase
  alias MyApp.Accounts

  describe "register_user/1" do
    test "creates user with valid attrs" do
      attrs = %{email: "user@example.com", password: "secret123"}
      assert {:ok, user} = Accounts.register_user(attrs)
      assert user.email == "user@example.com"
    end

    test "returns error with invalid email" do
      attrs = %{email: "invalid", password: "secret123"}
      assert {:error, changeset} = Accounts.register_user(attrs)
      assert "is invalid" in errors_on(changeset).email
    end
  end
end
```

**Rationale:** Public functions are your API contract. Test them thoroughly.

---

**PREFER** `describe` blocks to group related tests.

**Rationale:** Describe blocks provide structure and make test output readable.

---

**PREFER** async tests for isolated tests.

```elixir
# Good
use MyApp.DataCase, async: true

# Avoid async for tests that share state
use MyApp.DataCase  # async: false (default)
```

**Rationale:** Async tests run concurrently, speeding up test suite. Only disable for tests that share global state.

---

**MUST** use fixtures or factories for test data.

```elixir
# Good
defmodule MyApp.AccountsFixtures do
  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> Enum.into(%{email: "user#{System.unique_integer()}@example.com"})
      |> MyApp.Accounts.register_user()

    user
  end
end

# In tests
user = user_fixture(%{email: "test@example.com"})
```

**Rationale:** Fixtures centralize test data creation, reducing duplication and making tests maintainable.

---

**PREFER** testing behavior over implementation.

```elixir
# Good (tests public behavior)
test "register_user/1 sends welcome email" do
  assert {:ok, user} = Accounts.register_user(@valid_attrs)
  assert_email_sent(to: user.email, subject: "Welcome")
end

# Avoid (tests implementation details)
test "register_user/1 calls Mailer.send_welcome" do
  # Testing internal function calls
end
```

**Rationale:** Testing behavior allows refactoring implementation. Testing internals makes tests brittle.

---
