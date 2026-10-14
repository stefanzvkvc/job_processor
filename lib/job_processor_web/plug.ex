defmodule JobProcessorWeb.Plug do
  import Plug.Conn

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

    with {:ok, request_id} <- fetch_request_id(conn),
         {:ok, tasks} <- fetch_tasks(conn.body_params),
         :ok <- validate_required(tasks) do
      send_json(conn, 202, %{status: "accepted", request_id: request_id})
    else
      {:error, message} ->
        send_json(conn, 400, %{
          status: "error",
          message: message
        })
    end
  end

  defp send_json(conn, status, data) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(data))
  end

  defp fetch_request_id(conn) do
    case get_req_header(conn, "x-request-id") do
      [request_id | _] -> {:ok, request_id}
      _ -> {:error, "Missing mandatory HTTP header: X-Request-Id"}
    end
  end

  defp fetch_tasks(%{"tasks" => tasks = [_ | _]}) do
    tasks
    |> Enum.reject(&(&1 == %{}))
    |> case do
      [] -> {:error, "Task list can't be empty"}
      tasks -> {:ok, tasks}
    end
  end

  defp fetch_tasks(%{"tasks" => []}), do: {:error, "Task list can't be empty"}

  defp fetch_tasks(%{"tasks" => _invalid_type}),
    do: {:error, "Invalid tasks format, must be a list"}

  defp fetch_tasks(_other_payload), do: {:error, "Invalid payload"}

  defp validate_required([%{"name" => _name, "command" => _command} | tasks]),
    do: validate_required(tasks)

  defp validate_required([]), do: :ok
  defp validate_required(_other), do: {:error, "Missing mandatory fields"}
end
