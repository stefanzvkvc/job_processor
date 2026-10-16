defmodule JobProcessor.ScriptTest do
  use ExUnit.Case, async: true

  alias JobProcessor.{Script, TaskSpec}

  test "renders commands in order after the shebang and set -e" do
    tasks = [
      %TaskSpec{name: "a", command: "echo a"},
      %TaskSpec{name: "b", command: "echo b"}
    ]

    assert Script.render(tasks) == """
           #!/usr/bin/env bash
           set -e
           echo a
           echo b
           """
  end
end
