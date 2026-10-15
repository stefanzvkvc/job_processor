defmodule JobProcessorWeb.Plug do
  import Plug.Conn

  @allowed_methods ~w(POST)
  @allowed_paths ~w(/tasks)

  def init(options) do
    parser_opts =
      Plug.Parsers.init(
        parsers: [:json],
        pass: ["application/json"],
        json_decoder: Jason
      )

    Keyword.put(options, :parser_opts, parser_opts)
  end

  def call(conn, opts) do
    parser_opts = Keyword.fetch!(opts, :parser_opts)
    conn = Plug.Parsers.call(conn, parser_opts)

    method = conn.method
    request_path = conn.request_path

    with :ok <- check_method(method),
         :ok <- check_path(request_path) do
      send_json(conn, 200, %{status: :success, data: %{}})
    else
      {:error, status_code, message} ->
        send_json(conn, status_code, %{
          status: :error,
          message: message
        })
    end
  end

  defp check_method(method) when method in @allowed_methods, do: :ok
  defp check_method(_), do: {:error, 405, "Method Not Allowed"}

  defp check_path(path) when path in @allowed_paths, do: :ok
  defp check_path(_), do: {:error, 404, "Not Found"}

  defp send_json(conn, status_status, data) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status_status, Jason.encode!(data))
  end
end
