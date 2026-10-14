defmodule JobProcessorWeb.PlugTest do
  use ExUnit.Case, async: true
  import Plug.Test
  import Plug.Conn

  @opts JobProcessorWeb.Plug.init([])

  test "202: accepts valid tasks payload" do
    payload =
      Jason.encode!(%{
        "tasks" => [
          %{"name" => "task-1", "command" => "touch /tmp/file1"},
          %{"name" => "task-2", "command" => "cat /tmp/file1"}
        ]
      })

    conn =
      conn(:post, "/", payload)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("x-request-id", "req-123")
      |> JobProcessorWeb.Plug.call(@opts)

    assert conn.status == 202
    assert Jason.decode!(conn.resp_body) == %{"status" => "accepted", "request_id" => "req-123"}
  end

  test "202: skips empty objects but successfully processes surrounding valid maps" do
    payload =
      Jason.encode!(%{
        "tasks" => [
          %{},
          %{"name" => "task-1", "command" => "touch /tmp/file1"},
          %{}
        ]
      })

    conn =
      conn(:post, "/", payload)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("x-request-id", "req-123")
      |> JobProcessorWeb.Plug.call(@opts)

    assert conn.status == 202
  end

  test "400: fails when non-map types (like strings) are mixed into the tasks list" do
    payload =
      Jason.encode!(%{
        "tasks" => [
          %{"name" => "task-1", "command" => "touch /tmp/file1"},
          "malicious_string"
        ]
      })

    conn =
      conn(:post, "/", payload)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("x-request-id", "req-123")
      |> JobProcessorWeb.Plug.call(@opts)

    assert conn.status == 400
    response = Jason.decode!(conn.resp_body)
    assert response["status"] == "error"
    assert response["message"] == "Missing mandatory fields"
  end

  test "400: skips empty objects but fails if nothing else is left in the list" do
    payload = Jason.encode!(%{"tasks" => [%{}]})

    conn =
      conn(:post, "/", payload)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("x-request-id", "req-123")
      |> JobProcessorWeb.Plug.call(@opts)

    assert conn.status == 400
    response = Jason.decode!(conn.resp_body)
    assert response["message"] == "Task list can't be empty"
  end
end
