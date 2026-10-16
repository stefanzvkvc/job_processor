defmodule JobProcessor.TaskSpec do
  @moduledoc """
  Validates a single task from the request body: name, command and optional requires.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          name: String.t() | nil,
          command: String.t() | nil,
          requires: [String.t()] | nil
        }

  @primary_key false
  embedded_schema do
    field :name, :string
    field :command, :string
    field :requires, {:array, :string}
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(schema \\ %__MODULE__{}, params) do
    schema
    |> cast(params, [:name, :command, :requires])
    |> validate_required([:name, :command])
    |> validate_requires()
  end

  defp validate_requires(changeset) do
    case changeset.params["requires"] do
      requires when is_list(requires) ->
        if Enum.any?(requires, &blank?/1),
          do: add_error(changeset, :requires, "cannot contain blank or null names"),
          else: changeset

      _ ->
        changeset
    end
  end

  defp blank?(nil), do: true
  defp blank?(value) when is_binary(value), do: String.trim(value) == ""
  defp blank?(_), do: false
end
