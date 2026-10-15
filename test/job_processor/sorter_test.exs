defmodule JobProcessor.SorterTest do
  use ExUnit.Case, async: true

  alias JobProcessor.Sorter

  test "sorts tasks by their dependencies" do
    tasks = [
      %{"name" => "task-1", "command" => "touch /tmp/file1"},
      %{"name" => "task-2", "command" => "cat /tmp/file1", "requires" => ["task-3"]},
      %{
        "name" => "task-3",
        "command" => "echo 'Hello World!' > /tmp/file1",
        "requires" => ["task-1"]
      },
      %{"name" => "task-4", "command" => "rm /tmp/file1", "requires" => ["task-2", "task-3"]}
    ]

    assert {:ok,
            [
              %{"name" => "task-1", "command" => "touch /tmp/file1"},
              %{"name" => "task-3", "command" => "echo 'Hello World!' > /tmp/file1"},
              %{"name" => "task-2", "command" => "cat /tmp/file1"},
              %{"name" => "task-4", "command" => "rm /tmp/file1"}
            ]} = Sorter.sort(tasks)
  end

  test "keeps input order for tasks without dependencies" do
    tasks = [
      %{"name" => "b", "command" => "echo b"},
      %{"name" => "a", "command" => "echo a"}
    ]

    assert {:ok, [%{"name" => "b"}, %{"name" => "a"}]} = Sorter.sort(tasks)
  end

  test "accepts null requires" do
    tasks = [%{"name" => "a", "command" => "echo a", "requires" => nil}]

    assert {:ok, [%{"name" => "a", "command" => "echo a"}]} = Sorter.sort(tasks)
  end

  test "rejects duplicate task names" do
    tasks = [
      %{"name" => "a", "command" => "echo a"},
      %{"name" => "a", "command" => "echo again"}
    ]

    assert {:error, {:duplicate_names, ["a"]}} = Sorter.sort(tasks)
  end

  test "rejects an unknown dependency" do
    tasks = [%{"name" => "a", "command" => "echo a", "requires" => ["ghost"]}]

    assert {:error, {:unknown_dependency, "a", "ghost"}} = Sorter.sort(tasks)
  end

  test "rejects a circular dependency" do
    tasks = [
      %{"name" => "a", "command" => "echo a", "requires" => ["b"]},
      %{"name" => "b", "command" => "echo b", "requires" => ["a"]}
    ]

    assert {:error, {:cycle, ["a", "b"]}} = Sorter.sort(tasks)
  end
end
