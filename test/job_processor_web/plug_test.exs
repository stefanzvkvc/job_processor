defmodule JobProcessorWeb.PlugTest do
  use ExUnit.Case, async: true
  import Plug.Test
  import Plug.Conn

  @opts JobProcessorWeb.Plug.init([])

  test "method not allowed" do
    conn = json_request(:get, "/tasks", %{})
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

  test "rejects a missing tasks field" do
    conn = json_request(:post, "/tasks", %{})
    assert conn.status == 400

    assert %{
             "status" => "error",
             "message" => "Request body must be an object containing a tasks list",
             "errors" => %{}
           } = Jason.decode!(conn.resp_body)
  end

  test "rejects tasks when the field is not a list" do
    conn = json_request(:post, "/tasks", %{"tasks" => %{"name" => "task-1"}})
    assert conn.status == 400

    assert %{
             "status" => "error",
             "message" => "The tasks field must be a non-empty list",
             "errors" => %{}
           } = Jason.decode!(conn.resp_body)
  end

  test "rejects an empty tasks list" do
    conn = json_request(:post, "/tasks", %{"tasks" => []})
    assert conn.status == 400

    assert %{
             "status" => "error",
             "message" => "The tasks field must be a non-empty list",
             "errors" => %{}
           } = Jason.decode!(conn.resp_body)
  end

  test "rejects a tasks list containing non-object values" do
    conn = json_request(:post, "/tasks", %{"tasks" => ["not an object"]})
    assert conn.status == 400

    assert %{
             "status" => "error",
             "message" => "Each task must be a JSON object",
             "errors" => %{}
           } = Jason.decode!(conn.resp_body)
  end

  test "rejects a task with a missing name" do
    conn =
      json_request(:post, "/tasks", %{
        "tasks" => [
          %{"command" => "touch /tmp/file1"}
        ]
      })

    assert conn.status == 400

    assert %{
             "status" => "error",
             "message" => "Invalid task",
             "errors" => %{"name" => ["can't be blank"]}
           } = Jason.decode!(conn.resp_body)
  end

  test "rejects a task with a missing command" do
    conn =
      json_request(:post, "/tasks", %{
        "tasks" => [
          %{"name" => "task-1"}
        ]
      })

    assert conn.status == 400

    assert %{
             "status" => "error",
             "message" => "Invalid task",
             "errors" => %{"command" => ["can't be blank"]}
           } = Jason.decode!(conn.resp_body)
  end

  test "rejects a task with missing and blank required fields" do
    conn =
      json_request(:post, "/tasks", %{
        "tasks" => [
          %{"name" => "   "}
        ]
      })

    assert conn.status == 400

    assert %{
             "status" => "error",
             "message" => "Invalid task",
             "errors" => %{"command" => ["can't be blank"], "name" => ["can't be blank"]}
           } = Jason.decode!(conn.resp_body)
  end

  test "rejects a task when requires array contains non-string values" do
    conn =
      json_request(:post, "/tasks", %{
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
             "message" => "Invalid task",
             "errors" => %{"requires" => ["is invalid"]}
           } = Jason.decode!(conn.resp_body)
  end

  test "rejects a task when requires array contains empty values" do
    conn =
      json_request(:post, "/tasks", %{
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
             "message" => "Invalid task",
             "errors" => %{"requires" => ["cannot be an empty list"]}
           } = Jason.decode!(conn.resp_body)
  end

  test "rejects a list containing an invalid task" do
    conn =
      json_request(:post, "/tasks", %{
        "tasks" => [
          %{"name" => "task-1", "command" => "touch /tmp/file1"},
          %{"name" => "task-2"}
        ]
      })

    assert conn.status == 400

    assert %{
             "status" => "error",
             "message" => "Invalid task",
             "errors" => %{"command" => ["can't be blank"]}
           } = Jason.decode!(conn.resp_body)
  end

  test "accepts a valid tasks list" do
    conn =
      json_request(:post, "/tasks", %{
        "tasks" => [
          %{"name" => "task-1", "command" => "touch /tmp/file1"}
        ]
      })

    assert conn.status == 200

    assert %{"status" => "success", "data" => data} =
             Jason.decode!(conn.resp_body)

    assert data == %{}
  end

  defp json_request(method, path, payload) do
    conn(method, path, Jason.encode!(payload))
    |> put_req_header("content-type", "application/json")
    |> JobProcessorWeb.Plug.call(@opts)
  end
end
