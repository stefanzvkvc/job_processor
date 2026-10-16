defmodule JobProcessorWeb.PlugTest do
  use ExUnit.Case, async: true
  import Plug.Test
  import Plug.Conn

  @opts JobProcessorWeb.Plug.init([])
  @example %{
    "tasks" => [
      %{"name" => "task-1", "command" => "touch /tmp/file1"},
      %{"name" => "task-2", "command" => "cat /tmp/file1", "requires" => ["task-3"]},
      %{
        "name" => "task-3",
        "command" => "echo 'Hello World!' > /tmp/file1",
        "requires" => ["task-1"]
      },
      %{"name" => "task-4", "command" => "rm /tmp/file1", "requires" => ["task-2", "task-3"]}
    ]
  }

  test "method not allowed" do
    conn = json_request(:get, "/jobs", %{})
    assert conn.status == 405

    assert %{
             "status" => "error",
             "message" => "Method Not Allowed",
             "errors" => %{}
           } = Jason.decode!(conn.resp_body)
  end

  test "not found" do
    conn = json_request(:post, "/unhandled", %{})
    assert conn.status == 404

    assert %{
             "status" => "error",
             "message" => "Not Found",
             "errors" => %{}
           } = Jason.decode!(conn.resp_body)
  end

  test "rejects too many tasks" do
    tasks = for i <- 1..1001, do: %{"name" => "t#{i}", "command" => "echo #{i}"}
    conn = json_request(:post, "/jobs", %{"tasks" => tasks})

    assert conn.status == 400
    assert %{"message" => "A job can contain at most 1000 tasks"} = Jason.decode!(conn.resp_body)
  end

  test "rejects a body that is too large" do
    command = String.duplicate("x", 1_000_001)

    conn = json_request(:post, "/jobs", %{"tasks" => [%{"name" => "a", "command" => command}]})

    assert conn.status == 413
  end

  test "rejects a missing tasks field" do
    conn = json_request(:post, "/jobs", %{})
    assert conn.status == 400

    assert %{
             "status" => "error",
             "message" => "Request body must be an object containing a tasks list",
             "errors" => %{}
           } = Jason.decode!(conn.resp_body)
  end

  test "rejects tasks when the field is not a list" do
    conn = json_request(:post, "/jobs", %{"tasks" => %{"name" => "task-1"}})
    assert conn.status == 400

    assert %{
             "status" => "error",
             "message" => "The tasks field must be a non-empty list",
             "errors" => %{}
           } = Jason.decode!(conn.resp_body)
  end

  test "rejects an empty tasks list" do
    conn = json_request(:post, "/jobs", %{"tasks" => []})
    assert conn.status == 400

    assert %{
             "status" => "error",
             "message" => "The tasks field must be a non-empty list",
             "errors" => %{}
           } = Jason.decode!(conn.resp_body)
  end

  test "rejects a tasks list containing non-object values" do
    conn = json_request(:post, "/jobs", %{"tasks" => ["not an object"]})
    assert conn.status == 400

    assert %{
             "status" => "error",
             "message" => "Each task must be a JSON object",
             "errors" => %{}
           } = Jason.decode!(conn.resp_body)
  end

  test "rejects a task with a missing name" do
    conn =
      json_request(:post, "/jobs", %{
        "tasks" => [
          %{"command" => "touch /tmp/file1"}
        ]
      })

    assert conn.status == 400

    assert %{
             "status" => "error",
             "message" => "Invalid tasks",
             "errors" => %{"tasks[0]" => %{"name" => ["can't be blank"]}}
           } = Jason.decode!(conn.resp_body)
  end

  test "rejects a task with a missing command" do
    conn =
      json_request(:post, "/jobs", %{
        "tasks" => [
          %{"name" => "task-1"}
        ]
      })

    assert conn.status == 400

    assert %{
             "status" => "error",
             "message" => "Invalid tasks",
             "errors" => %{"tasks[0]" => %{"command" => ["can't be blank"]}}
           } = Jason.decode!(conn.resp_body)
  end

  test "rejects a task with missing and blank required fields" do
    conn =
      json_request(:post, "/jobs", %{
        "tasks" => [
          %{"name" => "   "}
        ]
      })

    assert conn.status == 400

    assert %{
             "status" => "error",
             "message" => "Invalid tasks",
             "errors" => %{
               "tasks[0]" => %{"command" => ["can't be blank"], "name" => ["can't be blank"]}
             }
           } = Jason.decode!(conn.resp_body)
  end

  test "rejects a task when requires array contains non-string values" do
    conn =
      json_request(:post, "/jobs", %{
        "tasks" => [
          %{
            "name" => "task-3",
            "command" => "echo 'Hello World!' > /tmp/file1",
            "requires" => ["task-1", 123]
          }
        ]
      })

    assert conn.status == 400

    assert %{
             "status" => "error",
             "message" => "Invalid tasks",
             "errors" => %{"tasks[0]" => %{"requires" => ["is invalid"]}}
           } = Jason.decode!(conn.resp_body)
  end

  test "rejects a task when requires array contains empty values" do
    conn =
      json_request(:post, "/jobs", %{
        "tasks" => [
          %{
            "name" => "task-4",
            "command" => "rm /tmp/file1",
            "requires" => ["      ", " "]
          }
        ]
      })

    assert conn.status == 400

    assert %{
             "status" => "error",
             "message" => "Invalid tasks",
             "errors" => %{
               "tasks[0]" => %{"requires" => ["cannot contain blank or null names"]}
             }
           } = Jason.decode!(conn.resp_body)
  end

  test "rejects a list containing an invalid task" do
    conn =
      json_request(:post, "/jobs", %{
        "tasks" => [
          %{"name" => "task-1", "command" => "touch /tmp/file1"},
          %{"name" => "task-2"}
        ]
      })

    assert conn.status == 400

    assert %{
             "status" => "error",
             "message" => "Invalid tasks",
             "errors" => %{"tasks[1]" => %{"command" => ["can't be blank"]}}
           } = Jason.decode!(conn.resp_body)
  end

  test "rejects a task when requires contains null" do
    conn =
      json_request(:post, "/jobs", %{
        "tasks" => [%{"name" => "a", "command" => "x", "requires" => ["task-1", nil]}]
      })

    assert conn.status == 400

    assert %{
             "errors" => %{
               "tasks[0]" => %{"requires" => ["cannot contain blank or null names"]}
             }
           } =
             Jason.decode!(conn.resp_body)
  end

  test "rejects malformed JSON" do
    conn = raw_request(:post, "/jobs", ~s({"tasks": [), "application/json")
    assert conn.status == 400

    assert %{
             "status" => "error",
             "message" => "Malformed JSON",
             "errors" => %{}
           } = Jason.decode!(conn.resp_body)
  end

  test "rejects a non-JSON content type" do
    conn = raw_request(:post, "/jobs", "tasks=task-1", "text/plain")
    assert conn.status == 415

    assert %{
             "status" => "error",
             "message" => "Content-Type must be application/json",
             "errors" => %{}
           } = Jason.decode!(conn.resp_body)
  end

  test "rejects a missing content type" do
    conn = conn(:post, "/jobs", Jason.encode!(@example)) |> JobProcessorWeb.Plug.call(@opts)
    assert conn.status == 415

    assert %{
             "status" => "error",
             "message" => "Content-Type must be application/json",
             "errors" => %{}
           } = Jason.decode!(conn.resp_body)
  end

  test "accepts a valid tasks list" do
    conn =
      json_request(:post, "/jobs", %{
        "tasks" => [
          %{"name" => "task-1", "command" => "touch /tmp/file1"}
        ]
      })

    assert conn.status == 200

    assert %{
             "status" => "success",
             "tasks" => [%{"command" => "touch /tmp/file1", "name" => "task-1"}]
           } =
             Jason.decode!(conn.resp_body)
  end

  test "returns sorted tasks as JSON" do
    conn = json_request(:post, "/jobs", @example)
    assert conn.status == 200

    assert %{
             "status" => "success",
             "tasks" => [
               %{"name" => "task-1", "command" => "touch /tmp/file1"},
               %{"name" => "task-3", "command" => "echo 'Hello World!' > /tmp/file1"},
               %{"name" => "task-2", "command" => "cat /tmp/file1"},
               %{"name" => "task-4", "command" => "rm /tmp/file1"}
             ]
           } = Jason.decode!(conn.resp_body)
  end

  test "returns sorted tasks as a bash script" do
    conn = json_request(:post, "/jobs", @example, [{"accept", "text/plain"}])
    assert conn.status == 200
    assert ["text/plain" <> _] = get_resp_header(conn, "content-type")

    assert conn.resp_body == """
           #!/usr/bin/env bash
           set -e
           touch /tmp/file1
           echo 'Hello World!' > /tmp/file1
           cat /tmp/file1
           rm /tmp/file1
           """
  end

  test "returns JSON when it is listed before text/plain in Accept" do
    conn = json_request(:post, "/jobs", @example, [{"accept", "application/json, text/plain"}])
    assert conn.status == 200
    assert ["application/json" <> _] = get_resp_header(conn, "content-type")
  end

  test "rejects a circular dependency" do
    conn =
      json_request(:post, "/jobs", %{
        "tasks" => [
          %{"name" => "a", "command" => "echo a", "requires" => ["b"]},
          %{"name" => "b", "command" => "echo b", "requires" => ["a"]}
        ]
      })

    assert conn.status == 422

    assert %{
             "status" => "error",
             "message" => "Circular dependency among: a, b"
           } = Jason.decode!(conn.resp_body)
  end

  test "rejects an unknown dependency" do
    conn =
      json_request(:post, "/jobs", %{
        "tasks" => [%{"name" => "a", "command" => "echo a", "requires" => ["ghost"]}]
      })

    assert conn.status == 422

    assert %{
             "status" => "error",
             "message" => "Task a requires unknown task ghost"
           } = Jason.decode!(conn.resp_body)
  end

  test "rejects duplicate task names" do
    conn =
      json_request(:post, "/jobs", %{
        "tasks" => [
          %{"name" => "a", "command" => "echo a"},
          %{"name" => "a", "command" => "echo again"}
        ]
      })

    assert conn.status == 422

    assert %{
             "status" => "error",
             "message" => "Duplicate task names: a"
           } = Jason.decode!(conn.resp_body)
  end

  defp json_request(method, path, payload, headers \\ []) do
    conn = conn(method, path, Jason.encode!(payload))

    headers
    |> Enum.reduce(conn, fn {key, value}, conn -> put_req_header(conn, key, value) end)
    |> put_req_header("content-type", "application/json")
    |> JobProcessorWeb.Plug.call(@opts)
  end

  defp raw_request(method, path, body, content_type) do
    conn(method, path, body)
    |> put_req_header("content-type", content_type)
    |> JobProcessorWeb.Plug.call(@opts)
  end
end
