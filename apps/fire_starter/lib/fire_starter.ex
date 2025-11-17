defmodule FireStarter do
  @moduledoc """
  <!-- ADD PURPOSE STATEMENT HERE -->

  ## Sub-Domains

  For information on each sub-domain, see:

  <!--- LIST SUBDOMAINS HERE. -->

  ## Ecto ERD

  ![Ecto ERD](./assets/erd.png) [View Larger Image](./assets/erd.png)
  """

  defmodule Attrs do
    @moduledoc """
    Represents attributes for record creation and updates.
    """

    @typedoc """
    A map of attributes with either string or atom keys.
    """
    @type t() :: %{required(binary()) => term()} | %{required(atom()) => term()}
  end

  @doc false
  def record do
    quote do
      use Ecto.Schema

      import Ecto.Changeset
      import Ecto.Query, warn: false
    end
  end

  @doc false
  def context do
    quote do
      alias Ecto.Changeset

      alias FireStarter.Attrs
      alias FireStarter.Repo

      # alias FireStarter.Accounts.Scope

      import Ecto.Query, warn: false
    end
  end

  @doc false
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
