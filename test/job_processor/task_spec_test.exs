defmodule JobProcessor.TaskSpecTest do
  use ExUnit.Case, async: true
  alias JobProcessor.TaskSpec

  test "a missing, null or empty requires becomes an empty list" do
    for params <- [
          %{"name" => "task-1", "command" => "touch /tmp/file1"},
          %{"name" => "task-1", "command" => "touch /tmp/file1", "requires" => nil},
          %{"name" => "task-1", "command" => "touch /tmp/file1", "requires" => []}
        ] do
      changeset = TaskSpec.changeset(params)

      assert changeset.valid?
      assert Ecto.Changeset.apply_changes(changeset).requires == []
    end
  end

  test "valid parameters return a valid changeset, with requires" do
    params = %{
      "name" => "task-2",
      "command" => "cat /tmp/file1",
      "requires" => ["task-3"]
    }

    changeset = TaskSpec.changeset(params)
    assert changeset.valid?
  end

  test "missing or blank fields return validation errors" do
    params = %{"name" => "   "}
    changeset = TaskSpec.changeset(params)

    refute changeset.valid?
    errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)

    assert errors.name == ["can't be blank"]
    assert errors.command == ["can't be blank"]
  end

  test "requires array must contain only strings" do
    params = %{
      "name" => "task-3",
      "command" => "echo 'Hello World!' > /tmp/file1",
      "requires" => ["task-1", 123]
    }

    changeset = TaskSpec.changeset(params)
    refute changeset.valid?

    errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)
    assert errors.requires == ["is invalid"]
  end

  test "requires array cannot contain blank names" do
    params = %{
      "name" => "task-4",
      "command" => "rm /tmp/file1",
      "requires" => ["      ", " "]
    }

    changeset = TaskSpec.changeset(params)
    refute changeset.valid?

    errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)
    assert errors.requires == ["cannot contain blank or null names"]
  end

  test "requires array cannot contain null value" do
    params = %{
      "name" => "task-4",
      "command" => "rm /tmp/file1",
      "requires" => ["task-1", nil]
    }

    changeset = TaskSpec.changeset(params)
    refute changeset.valid?

    errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)
    assert errors.requires == ["cannot contain blank or null names"]
  end

  test "fields with the wrong type are invalid" do
    valid = %{"name" => "task-1", "command" => "touch /tmp/file1"}

    for {field, value} <- [{"name", 1}, {"command", 1}, {"requires", "task-1"}] do
      changeset = TaskSpec.changeset(Map.put(valid, field, value))
      errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)

      assert errors == %{String.to_existing_atom(field) => ["is invalid"]}
    end
  end
end
