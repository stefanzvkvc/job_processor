defmodule JobProcessor.RequestTest do
  use ExUnit.Case, async: true
  alias JobProcessor.Request

  test "valid parameters return a valid changeset, without requires" do
    params = %{
      "name" => "task-1",
      "command" => "touch /tmp/file1"
    }

    changeset = Request.changeset(params)
    assert changeset.valid?
  end

  test "valid parameters return a valid changeset, with requires" do
    params = %{
      "name" => "task-2",
      "command" => "cat /tmp/file1",
      "requires" => ["task-3"]
    }

    changeset = Request.changeset(params)
    assert changeset.valid?
  end

  test "missing or blank fields return validation errors" do
    params = %{"name" => "   "}
    changeset = Request.changeset(params)

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

    changeset = Request.changeset(params)
    refute changeset.valid?

    errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)
    assert errors.requires == ["is invalid"]
  end

  test "requires array cannot be empty list" do
    params = %{
      "name" => "task-4",
      "command" => "rm /tmp/file1",
      "requires" => ["      ", " "]
    }

    changeset = Request.changeset(params)
    refute changeset.valid?

    errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)
    assert errors.requires == ["cannot be an empty list"]
  end
end
