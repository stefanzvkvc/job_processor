defmodule JobProcessor.Sorter do
  @spec sort([map()]) :: {:ok, [map()]} | {:error, String.t()}
  def sort(_tasks) do
    {:ok, %{}}
  end
end
