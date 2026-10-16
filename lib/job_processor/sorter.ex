defmodule JobProcessor.Sorter do
  @moduledoc """
  Orders tasks so that every task runs after the tasks it requires.

  Repeatedly takes the first remaining task whose dependencies are all done.
  If tasks remain but none of them is ready, they form (or depend on) a cycle.
  Tasks with no dependency between them keep their input order.
  """

  alias JobProcessor.TaskSpec

  @type error ::
          {:duplicate_names, [String.t()]}
          | {:unknown_dependency, task :: String.t(), dependency :: String.t()}
          | {:cycle, [String.t()]}

  @spec sort([TaskSpec.t()]) :: {:ok, [TaskSpec.t()]} | {:error, error()}
  def sort(tasks) do
    with :ok <- check_duplicates(tasks),
         :ok <- check_unknown_dependencies(tasks) do
      order(tasks, MapSet.new(), [])
    end
  end

  defp order([], _done, sorted), do: {:ok, Enum.reverse(sorted)}

  defp order(remaining, done, sorted) do
    case Enum.find(remaining, &ready?(&1, done)) do
      nil ->
        {:error, {:cycle, Enum.map(remaining, & &1.name)}}

      task ->
        order(
          List.delete(remaining, task),
          MapSet.put(done, task.name),
          [task | sorted]
        )
    end
  end

  defp ready?(task, done), do: Enum.all?(requires(task), &MapSet.member?(done, &1))

  defp requires(task), do: task.requires || []

  defp check_duplicates(tasks) do
    case for {name, n} <- Enum.frequencies_by(tasks, & &1.name), n > 1, do: name do
      [] -> :ok
      dupes -> {:error, {:duplicate_names, Enum.sort(dupes)}}
    end
  end

  defp check_unknown_dependencies(tasks) do
    names = MapSet.new(tasks, & &1.name)

    case for t <- tasks, dep <- requires(t), not MapSet.member?(names, dep), do: {t.name, dep} do
      [] -> :ok
      [{task, dep} | _] -> {:error, {:unknown_dependency, task, dep}}
    end
  end
end
