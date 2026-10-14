defmodule JobProcessorWeb.PlugTest do
  use ExUnit.Case, async: true
  import Plug.Test

  @opts JobProcessorWeb.Plug.init([])

  test "returns hello world" do
    # Create a test connection
    conn = conn(:get, "/test")

    # Invoke the plug
    conn = JobProcessorWeb.Plug.call(conn, @opts)

    # Assert the response and status
    assert conn.state == :sent
    assert conn.status == 200
    assert conn.resp_body == "Hello world"
  end
end
