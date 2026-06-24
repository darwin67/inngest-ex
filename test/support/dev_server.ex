defmodule Inngest.Test.DevServer do
  @moduledoc false

  use GenServer

  alias Inngest.HTTPClient.{Request, Response}

  @base_url "http://127.0.0.1:8288"
  @app_url "http://127.0.0.1:4000/api/inngest"
  @startup_retries 100
  @startup_interval 100
  @discovery_interval 2_000
  @log_limit 20

  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_) do
    Process.flag(:trap_exit, true)

    port =
      Port.open({:spawn_executable, executable()}, [
        :binary,
        :exit_status,
        {:args, ["dev", "-u", @app_url]},
        :stderr_to_stdout
      ])

    wait_until_ready()
    Process.sleep(@discovery_interval)

    {:ok, %{port: port, os_pid: os_pid(port), logs: []}}
  end

  @impl true
  def handle_info({_port, {:data, data}}, state) do
    {:noreply, %{state | logs: keep_logs(state.logs, data)}}
  end

  @impl true
  def handle_info({_port, {:exit_status, 0}}, state), do: {:noreply, state}

  @impl true
  def handle_info({_port, {:exit_status, status}}, state) do
    {:stop, {:inngest_cli_exit, status, Enum.join(state.logs)}, state}
  end

  @impl true
  def terminate(_reason, %{port: port, os_pid: os_pid}) when is_port(port) do
    if Port.info(port), do: Port.close(port)
    terminate_os_process(os_pid)
  end

  def terminate(_reason, _state), do: :ok

  def run_ids(event_id) do
    get("/v1/events/#{event_id}/runs", query: cache_bust())
    |> parse_resp()
  end

  def fn_run(run_id) do
    get("/v1/runs/#{run_id}", query: cache_bust())
    |> parse_resp()
  end

  def list_events() do
    get("/v1/events", query: cache_bust())
    |> parse_resp()
  end

  defp get(path, opts \\ []) do
    query = Keyword.get(opts, :query)

    Inngest.HTTPClient.Finch.request(%Request{
      method: :get,
      base_url: @base_url,
      path: path,
      query: query,
      url: build_url(path, query),
      headers: [{"cache-control", "no-cache"}]
    })
  end

  defp executable do
    System.find_executable("inngest-cli") ||
      System.find_executable("inngest") ||
      raise "inngest-cli executable is required for integration tests"
  end

  defp os_pid(port) do
    case Port.info(port, :os_pid) do
      {:os_pid, pid} -> pid
      nil -> nil
    end
  end

  defp terminate_os_process(pid) when is_integer(pid) do
    pid = Integer.to_string(pid)

    System.cmd("kill", ["-TERM", pid], stderr_to_stdout: true)
    Process.sleep(100)

    if process_alive?(pid) do
      System.cmd("kill", ["-KILL", pid], stderr_to_stdout: true)
    end

    :ok
  rescue
    _ -> :ok
  end

  defp terminate_os_process(_pid), do: :ok

  defp process_alive?(pid) do
    case System.cmd("kill", ["-0", pid], stderr_to_stdout: true) do
      {_, 0} -> true
      _ -> false
    end
  rescue
    _ -> false
  end

  defp wait_until_ready(retries \\ @startup_retries)

  defp wait_until_ready(0), do: raise("inngest-cli dev server did not start")

  defp wait_until_ready(retries) do
    case get("/v1/events") do
      {:ok, %Response{status: 200}} ->
        :ok

      _ ->
        retry_wait(retries)
    end
  rescue
    _ -> retry_wait(retries)
  end

  defp retry_wait(retries) do
    Process.sleep(@startup_interval)
    wait_until_ready(retries - 1)
  end

  defp cache_bust do
    [{"t", System.unique_integer([:positive])}]
  end

  defp keep_logs(logs, data) do
    logs
    |> Kernel.++([data])
    |> Enum.take(-@log_limit)
  end

  defp parse_resp(result) do
    case result do
      {:ok, %Response{status: 200, body: resp}} ->
        if is_binary(resp) do
          Jason.decode(resp)
        else
          {:ok, resp}
        end

      {:ok, %Response{status: 404}} ->
        {:error, :not_found}

      {:ok, %Response{status: 400, body: resp}} ->
        with true <- is_binary(resp),
             {:ok, body} <- Jason.decode(resp) do
          {:error, Map.get(body, "error")}
        else
          false -> {:error, Map.get(resp, "error")}
          _ -> {:error, :unknown_error}
        end
    end
  end

  defp build_url(path, nil), do: build_url(path, [])

  defp build_url(path, query) do
    url = @base_url <> path

    case URI.encode_query(query) do
      "" -> url
      encoded_query -> url <> "?" <> encoded_query
    end
  end
end
