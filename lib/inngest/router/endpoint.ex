defmodule Inngest.Router.Endpoint do
  import Plug.Conn
  alias Inngest.Function.Args
  alias Inngest.Handler

  @content_type "application/json"

  def register(conn, %{funcs: funcs} = _params) do
    {status, resp} =
      case Inngest.Client.register(funcs) do
        :ok ->
          {200, %{}}

        {:error, error} ->
          {400, error}
      end

    resp =
      case Jason.encode(resp) do
        {:ok, val} -> val
        {:error, error} -> error
      end

    conn
    |> put_resp_content_type(@content_type)
    |> send_resp(status, resp)
  end

  def invoke(
        %{assigns: %{funcs: funcs}} = conn,
        %{"event" => event, "ctx" => ctx, "fnId" => slug} = _params
      ) do
    # NOTES:
    # *********  INVOKE  **********
    # Check fnId for function, stepId for step
    # Extract passed in state of function exec.
    # Iterate through steps,
    # - Generate a new UnhashedOp with name, op, and data?
    # - Check if the HashedOp version is passed in via state
    # - If yes, mark the response data for step X with data of that state
    # - If no, execute the step, and get its response
    # - Generate response, ref RESPONSE below for expected structure
    #
    #
    # *********  RESPONSE  ***********
    # Each results has a specific meaning to it.
    # status, data
    # 206, generatorcode -> continue on step execution
    # 200, resp -> completed all execution (including steps) of function
    # 400, error -> non retriable error
    # 500, error -> retriable error
    #

    args = %Args{
      event: Inngest.Event.from(event),
      run_id: Map.get(ctx, "run_id")
    }

    func = Map.get(funcs, slug)
    {status, resp} = Handler.invoke(conn, func, args)

    conn
    |> put_resp_content_type(@content_type)
    |> send_resp(status, resp)
  end
end
