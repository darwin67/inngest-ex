defmodule Inngest.Test.DevServer do
  @moduledoc false

  use GenServer

  @base_url "http://127.0.0.1:8288"

  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_) do
    Process.flag(:trap_exit, true)

    task =
      Task.async(fn ->
        System.cmd(
          "inngest-cli",
          ["dev", "-u", "http://127.0.0.1:4000/api/inngest"],
          stderr_to_stdout: true
        )
      end)

    {:ok, task.pid}
  end

  def run_ids(event_id) do
    client()
    |> Tesla.get("/v1/events/#{event_id}/runs")
    |> parse_resp()
  end

  def fn_run(run_id) do
    client()
    |> Tesla.get("/v1/runs/#{run_id}")
    |> parse_resp()
  end

  defp client() do
    middleware = [
      {Tesla.Middleware.BaseUrl, @base_url},
      Tesla.Middleware.JSON
    ]

    Tesla.client(middleware)
  end

  defp parse_resp(result) do
    case result do
      {:ok, %Tesla.Env{status: 200, body: resp}} ->
        if is_binary(resp) do
          Jason.decode(resp)
        else
          {:ok, resp}
        end

      {:ok, %Tesla.Env{status: 404}} ->
        {:error, :not_found}

      {:ok, %Tesla.Env{status: 400, body: resp}} ->
        with true <- is_binary(resp),
             {:ok, body} <- Jason.decode(resp) do
          {:error, Map.get(body, "error")}
        else
          false -> {:error, Map.get(resp, "error")}
          _ -> {:error, :unknown_error}
        end
    end
  end
end
