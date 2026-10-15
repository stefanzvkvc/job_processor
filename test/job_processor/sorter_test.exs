defmodule JobProcessor.SorterTest do
  use ExUnit.Case, async: true

  alias JobProcessor.{Request, Sorter}

  test "sorts tasks by their dependencies" do
    tasks = [
      %Request{name: "task-1", command: "touch /tmp/file1"},
      %Request{name: "task-2", command: "cat /tmp/file1", requires: ["task-3"]},
      %Request{
        name: "task-3",
        command: "echo 'Hello World!' > /tmp/file1",
        requires: ["task-1"]
      },
      %Request{name: "task-4", command: "rm /tmp/file1", requires: ["task-2", "task-3"]}
    ]

    assert {:ok, sorted} = Sorter.sort(tasks)
    assert Enum.map(sorted, & &1.name) == ["task-1", "task-3", "task-2", "task-4"]
  end

  test "keeps input order for tasks without dependencies" do
    tasks = [
      %Request{name: "b", command: "echo b"},
      %Request{name: "a", command: "echo a"}
    ]

    assert {:ok, [%Request{name: "b"}, %Request{name: "a"}]} = Sorter.sort(tasks)
  end

  test "rejects duplicate task names" do
    tasks = [
      %Request{name: "a", command: "echo a"},
      %Request{name: "a", command: "echo again"}
    ]

    assert {:error, {:duplicate_names, ["a"]}} = Sorter.sort(tasks)
  end

  test "rejects an unknown dependency" do
    tasks = [%Request{name: "a", command: "echo a", requires: ["ghost"]}]

    assert {:error, {:unknown_dependency, "a", "ghost"}} = Sorter.sort(tasks)
  end

  test "rejects a circular dependency" do
    tasks = [
      %Request{name: "a", command: "echo a", requires: ["b"]},
      %Request{name: "b", command: "echo b", requires: ["a"]}
    ]

    assert {:error, {:cycle, ["a", "b"]}} = Sorter.sort(tasks)
  end
end
