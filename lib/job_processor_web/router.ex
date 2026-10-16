defmodule JobProcessorWeb.Router do
  @moduledoc """
  Routes `POST /jobs`: parses and validates the job, sorts its tasks and
  responds with JSON or a bash script, depending on the `Accept` header.
  """

  use Plug.Router

  alias JobProcessor.{Sorter, TaskSpec}

  @max_body_bytes 1_000_000
  @max_tasks 1_000
  @parser_opts Plug.Parsers.init(
                 parsers: [:json],
                 pass: ["application/json"],
                 json_decoder: Jason,
                 length: @max_body_bytes
               )

  plug :match
  plug :parse_body
  plug :dispatch

  post "/jobs" do
    with :ok <- validate_content_type(conn),
         :ok <- validate_body_params(conn.body_params),
         {:ok, tasks} <- validate_tasks(conn.body_params["tasks"]),
         {:ok, sorted} <- sort(tasks) do
      respond(conn, sorted)
    else
      {:error, status_code, message, errors} -> send_error(conn, status_code, message, errors)
    end
  end

  match "/jobs" do
    conn
    |> put_resp_header("allow", "POST")
    |> send_error(405, "Method Not Allowed")
  end

  match _ do
    send_error(conn, 404, "Not Found")
  end

  # Plug.Parsers raises on bodies it cannot accept; these are client errors,
  # so they get the same JSON error response as every other bad request.
  defp parse_body(conn, _opts) do
    Plug.Parsers.call(conn, @parser_opts)
  rescue
    Plug.Parsers.ParseError ->
      conn |> send_error(400, "Malformed JSON") |> halt()

    Plug.Parsers.RequestTooLargeError ->
      conn |> send_error(413, "Request body is too large") |> halt()

    Plug.Parsers.UnsupportedMediaTypeError ->
      conn |> send_error(415, "Content-Type must be application/json") |> halt()
  end

  # Plug.Parsers skips requests without a Content-Type, so check for it here.
  defp validate_content_type(conn) do
    case get_req_header(conn, "content-type") do
      [] -> error(415, "Content-Type must be application/json")
      _ -> :ok
    end
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

  defp error(status_code, message, errors \\ %{}), do: {:error, status_code, message, errors}

  defp send_error(conn, status_code, message, errors \\ %{}) do
    send_json(conn, status_code, %{status: :error, message: message, errors: errors})
  end

  defp send_json(conn, status_code, data) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status_code, Jason.encode!(data))
  end

  defp format_error({:duplicate_names, names}),
    do: "Duplicate task names: #{Enum.join(names, ", ")}"

  defp format_error({:unknown_dependency, task, dep}),
    do: "Task #{task} requires unknown task #{dep}"

  defp format_error({:cycle, names}), do: "Circular dependency among: #{Enum.join(names, ", ")}"
end
