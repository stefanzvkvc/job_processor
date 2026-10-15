defmodule JobProcessorWeb.PlugTest do
  use ExUnit.Case, async: true
  import Plug.Test
  import Plug.Conn

  @opts JobProcessorWeb.Plug.init([])

  test "200" do
    conn = json_request(:post, "/tasks", %{})

    assert conn.status == 200
    assert %{"status" => "success", "data" => data} = Jason.decode!(conn.resp_body)
    assert data == %{}
  end

  test "405" do
    conn = json_request(:get, "/tasks", %{})
    assert conn.status == 405

    assert %{"status" => "error", "message" => "Method Not Allowed"} =
             Jason.decode!(conn.resp_body)
  end

  test "404" do
    conn = json_request(:post, "/unhandled", %{})
    assert conn.status == 404
    assert %{"status" => "error", "message" => "Not Found"} = Jason.decode!(conn.resp_body)
  end

  defp json_request(method, path, payload) do
    conn(method, path, Jason.encode!(payload))
    |> put_req_header("content-type", "application/json")
    |> JobProcessorWeb.Plug.call(@opts)
  end
end
