defmodule JobProcessor.SorterTest do
  use ExUnit.Case, async: true

  alias JobProcessor.{Sorter, TaskSpec}

  test "sorts tasks by their dependencies" do
    tasks = [
      %TaskSpec{name: "task-1", command: "touch /tmp/file1"},
      %TaskSpec{name: "task-2", command: "cat /tmp/file1", requires: ["task-3"]},
      %TaskSpec{
        name: "task-3",
        command: "echo 'Hello World!' > /tmp/file1",
        requires: ["task-1"]
      },
      %TaskSpec{name: "task-4", command: "rm /tmp/file1", requires: ["task-2", "task-3"]}
    ]

    assert {:ok, sorted} = Sorter.sort(tasks)
    assert Enum.map(sorted, & &1.name) == ["task-1", "task-3", "task-2", "task-4"]
  end

  test "keeps input order for tasks without dependencies" do
    tasks = [
      %TaskSpec{name: "b", command: "echo b"},
      %TaskSpec{name: "a", command: "echo a"}
    ]

    assert {:ok, [%TaskSpec{name: "b"}, %TaskSpec{name: "a"}]} = Sorter.sort(tasks)
  end

  test "rejects duplicate task names" do
    tasks = [
      %TaskSpec{name: "a", command: "echo a"},
      %TaskSpec{name: "a", command: "echo again"}
    ]

    assert {:error, {:duplicate_names, ["a"]}} = Sorter.sort(tasks)
  end

  test "rejects an unknown dependency" do
    tasks = [%TaskSpec{name: "a", command: "echo a", requires: ["ghost"]}]

    assert {:error, {:unknown_dependency, "a", "ghost"}} = Sorter.sort(tasks)
  end

  test "rejects a circular dependency" do
    tasks = [
      %TaskSpec{name: "a", command: "echo a", requires: ["b"]},
      %TaskSpec{name: "b", command: "echo b", requires: ["a"]}
    ]

    assert {:error, {:cycle, ["a", "b"]}} = Sorter.sort(tasks)
  end

  test "sorts a diamond so the shared dependency runs first" do
    tasks = [
      %TaskSpec{name: "a", command: "echo a", requires: ["b", "c"]},
      %TaskSpec{name: "b", command: "echo b", requires: ["d"]},
      %TaskSpec{name: "c", command: "echo c", requires: ["d"]},
      %TaskSpec{name: "d", command: "echo d"}
    ]

    assert {:ok, sorted} = Sorter.sort(tasks)
    assert Enum.map(sorted, & &1.name) == ["d", "b", "c", "a"]
  end

  test "sorts a long chain given in reverse order" do
    names = for i <- 1..100, do: "t#{i}"

    tasks =
      for {name, previous} <- Enum.zip(names, [nil | names]) do
        %TaskSpec{name: name, command: "echo #{name}", requires: List.wrap(previous)}
      end

    assert {:ok, sorted} = Sorter.sort(Enum.reverse(tasks))
    assert Enum.map(sorted, & &1.name) == names
  end

  test "rejects a task that requires itself" do
    tasks = [%TaskSpec{name: "a", command: "echo a", requires: ["a"]}]

    assert {:error, {:cycle, ["a"]}} = Sorter.sort(tasks)
  end

  test "reports tasks that depend on a cycle as part of it" do
    tasks = [
      %TaskSpec{name: "a", command: "echo a", requires: ["b"]},
      %TaskSpec{name: "b", command: "echo b", requires: ["a"]},
      %TaskSpec{name: "c", command: "echo c", requires: ["a"]}
    ]

    assert {:error, {:cycle, ["a", "b", "c"]}} = Sorter.sort(tasks)
  end

  test "reports duplicate names before unknown dependencies" do
    tasks = [
      %TaskSpec{name: "a", command: "echo a"},
      %TaskSpec{name: "a", command: "echo again", requires: ["ghost"]}
    ]

    assert {:error, {:duplicate_names, ["a"]}} = Sorter.sort(tasks)
  end
end
