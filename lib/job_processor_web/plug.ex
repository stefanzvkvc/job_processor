defmodule JobProcessorWeb.Plug do
  @moduledoc """
  Handles `POST /jobs`: parses and validates the job, sorts its tasks and
  responds with JSON or a bash script, depending on the `Accept` header.
  """

  alias JobProcessor.{Sorter, TaskSpec}
  import Plug.Conn

  @allowed_methods ~w(POST)
  @allowed_paths ~w(/jobs)
  @max_body_bytes 1_000_000
  @max_tasks 1_000

  def init(options) do
    parser_opts =
      Plug.Parsers.init(
        parsers: [:json],
        pass: ["application/json"],
        json_decoder: Jason,
        length: @max_body_bytes,
        read_timeout: 5_000
      )

    Keyword.put(options, :parser_opts, parser_opts)
  end

  def call(conn, opts) do
    parser_opts = Keyword.fetch!(opts, :parser_opts)
    method = conn.method
    request_path = conn.request_path

    with :ok <- validate_method(method),
         :ok <- validate_path(request_path),
         {:ok, conn} <- parse_body(conn, parser_opts),
         :ok <- validate_body_params(conn.body_params),
         {:ok, tasks} <- validate_tasks(conn.body_params["tasks"]),
         {:ok, sorted} <- sort(tasks) do
      respond(conn, sorted)
    else
      {:error, status_code, details} ->
        send_json(conn, status_code, Map.put(details, :status, :error))
    end
  end

  defp validate_method(method) when method in @allowed_methods, do: :ok
  defp validate_method(_), do: error(405, "Method Not Allowed")

  defp validate_path(path) when path in @allowed_paths, do: :ok
  defp validate_path(_), do: error(404, "Not Found")

  defp parse_body(conn, parser_opts) do
    case get_req_header(conn, "content-type") do
      [] -> error(415, "Content-Type must be application/json")
      _ -> {:ok, Plug.Parsers.call(conn, parser_opts)}
    end
  rescue
    Plug.Parsers.ParseError -> error(400, "Malformed JSON")
    Plug.Parsers.RequestTooLargeError -> error(413, "Request body is too large")
    Plug.Parsers.UnsupportedMediaTypeError -> error(415, "Content-Type must be application/json")
  end

  defp validate_body_params(%{"tasks" => tasks})
       when is_list(tasks) and length(tasks) > @max_tasks do
    error(400, "A job can contain at most #{@max_tasks} tasks")
  end

  defp validate_body_params(%{"tasks" => tasks})
       when is_list(tasks) and tasks != [] do
    if Enum.all?(tasks, &is_map/1) do
      :ok
    else
      error(400, "Each task must be a JSON object")
    end
  end

  defp validate_body_params(%{"tasks" => _}) do
    error(400, "The tasks field must be a non-empty list")
  end

  defp validate_body_params(_body_params) do
    error(400, "Request body must be an object containing a tasks list")
  end

  defp validate_tasks(tasks) do
    changesets = Enum.map(tasks, &TaskSpec.changeset/1)

    errors =
      for {changeset, i} <- Enum.with_index(changesets), not changeset.valid?, into: %{} do
        {"tasks[#{i}]", Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)}
      end

    if errors == %{},
      do: {:ok, Enum.map(changesets, &Ecto.Changeset.apply_changes/1)},
      else: error(400, "Invalid tasks", errors)
  end

  defp sort(tasks) do
    case Sorter.sort(tasks) do
      {:ok, sorted} -> {:ok, sorted}
      {:error, reason} -> error(422, format_error(reason))
    end
  end

  defp respond(conn, sorted) do
    if wants_bash?(conn) do
      script =
        Enum.join(["#!/usr/bin/env bash", "set -e" | Enum.map(sorted, & &1.command)], "\n") <>
          "\n"

      conn
      |> put_resp_content_type("text/plain")
      |> send_resp(200, script)
    else
      send_json(conn, 200, %{
        status: :success,
        tasks: Enum.map(sorted, &Map.take(&1, [:name, :command]))
      })
    end
  end

  defp send_json(conn, status_code, data) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status_code, Jason.encode!(data))
  end

  defp wants_bash?(conn) do
    case get_req_header(conn, "accept") do
      [accept | _] ->
        accept
        |> String.split(",")
        |> hd()
        |> String.trim()
        |> String.starts_with?(["text/plain", "text/x-shellscript"])

      [] ->
        false
    end
  end

  defp error(status_code, message, errors \\ %{}) do
    {:error, status_code, %{message: message, errors: errors}}
  end

  defp format_error({:duplicate_names, names}),
    do: "Duplicate task names: #{Enum.join(names, ", ")}"

  defp format_error({:unknown_dependency, task, dep}),
    do: "Task #{task} requires unknown task #{dep}"

  defp format_error({:cycle, names}), do: "Circular dependency among: #{Enum.join(names, ", ")}"
end
