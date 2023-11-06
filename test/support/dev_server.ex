defmodule Inngest.Test.DevServer do
  @moduledoc false

  use GenServer

  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_) do
    Process.flag(:trap_exit, true)

    task =
      Task.async(fn ->
        System.cmd("inngest-cli", [
          "dev",
          "-u",
          "http://127.0.0.1:4000/api/inngest"
        ])
      end)

    {:ok, task.pid}
  end

  @impl true
  def terminate(_, _) do
    IO.inspect("Terminating...")
    System.cmd("pkill", ["inngest-cli"])
  end

  @impl true
  def handle_info({:EXIT, _from, _reason}, _) do
    IO.inspect("handling exit...")

    System.cmd("pkill", ["inngest-cli"])
    {:noreply, nil}
  end
end
