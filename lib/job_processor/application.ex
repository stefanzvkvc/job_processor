defmodule JobProcessor.Application do
  @moduledoc false

  use Application

  @impl Application
  def start(_type, _args) do
    # List all child processes to be supervised
    children = if Application.fetch_env!(:job_processor, :server), do: [http_server()], else: []

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: JobProcessor.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp http_server do
    {Plug.Cowboy,
     scheme: :http,
     plug: JobProcessorWeb.Router,
     port: Application.fetch_env!(:job_processor, :port),
     transport_options: [max_connections: 1_000],
     protocol_options: [idle_timeout: 15_000, request_timeout: 5_000]}
  end
end
