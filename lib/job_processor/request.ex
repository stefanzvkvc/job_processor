defmodule JobProcessor.Request do
  @moduledoc """
  Defines the data contract using in-memory schema.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:name, :string)
    field(:command, :string)
    field(:requires, {:array, :string})
  end

  def changeset(schema \\ %__MODULE__{}, params) do
    schema
    |> cast(params, [:name, :command, :requires])
    |> validate_required([:name, :command])
    |> validate_requires()
  end

  defp validate_requires(changeset) do
    case get_change(changeset, :requires) do
      requires when is_list(requires) ->
        if requires == [] or Enum.member?(requires, nil),
          do: add_error(changeset, :requires, "must be a non-empty list of task names"),
          else: changeset

      _ ->
        changeset
    end
  end
end
