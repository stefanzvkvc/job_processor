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
         :ok <- check_path(request_path),
         :ok <- check_body_params(conn.body_params),
         :ok <- check_tasks(conn.body_params) do
      # call JobProcessor.Sorter
      # check Accpept header
      # return response
      send_json(conn, 200, %{status: :success, data: %{}})
    else
      {:error, status_code, details} ->
        send_json(conn, status_code, Map.put(details, :status, :error))
    end
  end

  defp check_method(method) when method in @allowed_methods, do: :ok
  defp check_method(_), do: error(405, "Method Not Allowed")

  defp check_path(path) when path in @allowed_paths, do: :ok
  defp check_path(_), do: error(404, "Not Found")

  defp check_body_params(%{"tasks" => tasks})
       when is_list(tasks) and tasks != [] do
    if Enum.all?(tasks, &is_map/1) do
      :ok
    else
      error(400, "Each task must be a JSON object")
    end
  end

  defp check_body_params(%{"tasks" => _}) do
    error(400, "The tasks field must be a non-empty list")
  end

  defp check_body_params(_body_params) do
    error(400, "Request body must be an object containing a tasks list")
  end

  defp check_tasks(%{"tasks" => tasks}) do
    changesets = Enum.map(tasks, &JobProcessor.Request.changeset/1)

    case Enum.find(changesets, &(not &1.valid?)) do
      nil ->
        :ok

      changeset ->
        errors =
          Ecto.Changeset.traverse_errors(changeset, fn {message, _opts} ->
            message
          end)

        error(400, "Invalid task", errors)
    end
  end

  defp send_json(conn, status_status, data) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status_status, Jason.encode!(data))
  end

  defp error(status_code, message, errors \\ %{}) do
    {:error, status_code, %{message: message, errors: errors}}
  end
end
