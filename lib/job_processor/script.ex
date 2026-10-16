defmodule JobProcessor.Script do
  @moduledoc """
  Renders sorted tasks as a bash script.

  The script starts with `set -e`, so it stops at the first failing command
  and no task runs after a task it depends on has failed.
  """

  alias JobProcessor.TaskSpec

  @spec render([TaskSpec.t()]) :: String.t()
  def render(tasks) do
    lines = ["#!/usr/bin/env bash", "set -e" | Enum.map(tasks, & &1.command)]
    Enum.join(lines, "\n") <> "\n"
  end
end
