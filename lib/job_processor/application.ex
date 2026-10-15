defmodule JobProcessor.Application do
  @moduledoc false

  use Application

  @impl Application
  def start(_type, _args) do
    # List all child processes to be supervised
    children = [
      {Plug.Cowboy, scheme: :http, plug: JobProcessorWeb.Plug, port: 4000}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: JobProcessor.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
