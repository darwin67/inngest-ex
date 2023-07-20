defmodule Inngest.Function do
  @moduledoc """
  Module to be used within user code to setup an Inngest function.
  Making it servable and invokable.
  """
  alias Inngest.Config
  alias Inngest.Function.{Step, Trigger}

  @doc """
  Returns the function's human-readable ID, such as "sign-up-flow"
  """
  @callback slug() :: String.t()

  @doc """
  Returns the function name
  """
  @callback name() :: String.t()

  @doc """
  Returns the event name or schedule that triggers the function
  """
  @callback trigger() :: Trigger.t()

  @reserved [:run, :step, :sleep]

  defmacro __using__(opts) do
    quote location: :keep do
      unless Inngest.Function.__register__(__MODULE__, unquote(opts)) do
        # placeholder
      end

      alias Inngest.Client
      alias Inngest.Function.{Trigger, Step}
      # import Inngest.Function, only: [step: 2, step: 3]
      import Inngest.Function
      @before_compile unquote(__MODULE__)

      @behaviour Inngest.Function

      @opts unquote(opts)

      # TOOD: Use app name as prefix
      @fn_slug if Keyword.get(@opts, :id),
                 do: Keyword.get(@opts, :id),
                 else:
                   Keyword.get(@opts, :name)
                   |> String.replace(~r/[\.\/\s]+/, "-")
                   |> String.downcase()

      @impl true
      def slug(), do: @fn_slug

      @impl true
      def name(), do: Keyword.get(@opts, :name)

      @impl true
      def trigger(), do: @opts |> Map.new() |> trigger()
      defp trigger(%{event: event} = _opts), do: %Trigger{event: event}
      defp trigger(%{cron: cron} = _opts), do: %Trigger{cron: cron}

      def step(),
        do: %{
          step: %Step{
            id: :step,
            name: "step",
            runtime: %Step.RunTime{
              url: "#{Config.app_host()}/api/inngest?fnId=#{slug()}&step=step"
            },
            retries: %Step.Retry{}
          }
        }

      def steps(), do: __handler__().steps

      def serve() do
        %{
          id: slug(),
          name: name(),
          triggers: [trigger()],
          steps: step(),
          mod: __MODULE__
        }
      end

      def send(events) do
        # NOTE: keep this for now so we can add things like tracing in the future
        Client.send(events, [])
      end
    end
  end

  def __register__(module, _opts) do
    registered? = Module.has_attribute?(module, :inngest_fn_steps)

    unless registered? do
      accumulate_attributes = [
        :inngest_fn_steps
      ]

      Enum.each(
        accumulate_attributes,
        &Module.register_attribute(module, &1, accumulate: true, persist: true)
      )
    end

    registered?
  end

  defmacro run(message, var \\ quote(do: _), contents) do
    unless is_tuple(var) do
      IO.warn(
        "step context is always a map. The pattern " <>
          "#{inspect(Macro.to_string(var))} will never match",
        Macro.Env.stacktrace(__CALLER__)
      )
    end

    contents =
      case contents do
        [do: block] ->
          quote do
            unquote(block)
          end

        _ ->
          quote do
            try(unquote(contents))
          end
      end

    var = Macro.escape(var)
    contents = Macro.escape(contents, unquote: true)

    %{module: mod, file: file, line: line} = __CALLER__

    quote bind_quoted: [
            var: var,
            contents: contents,
            message: message,
            mod: mod,
            file: file,
            line: line
          ] do
      slug = Inngest.Function.register_step(mod, file, line, :exec_run, message, [])
      def unquote(slug)(unquote(var)), do: unquote(contents)
    end
  end

  defmacro step(message, var \\ quote(do: _), contents) do
    unless is_tuple(var) do
      IO.warn(
        "step context is always a map. The pattern " <>
          "#{inspect(Macro.to_string(var))} will never match",
        Macro.Env.stacktrace(__CALLER__)
      )
    end

    contents =
      case contents do
        [do: block] ->
          quote do
            unquote(block)
          end

        _ ->
          quote do
            try(unquote(contents))
          end
      end

    var = Macro.escape(var)
    contents = Macro.escape(contents, unquote: true)

    %{module: mod, file: file, line: line} = __CALLER__

    quote bind_quoted: [
            var: var,
            contents: contents,
            message: message,
            mod: mod,
            file: file,
            line: line
          ] do
      slug = Inngest.Function.register_step(mod, file, line, :step_run, message)

      def unquote(slug)(unquote(var)), do: unquote(contents)
    end
  end

  defmacro sleep(message, var \\ quote(do: _), contents) do
    unless is_tuple(var) do
      IO.warn(
        "step context is always a map. The pattern " <>
          "#{inspect(Macro.to_string(var))} will never match",
        Macro.Env.stacktrace(__CALLER__)
      )
    end

    contents =
      case contents do
        [do: block] ->
          quote do
            unquote(block)
          end

        _ ->
          quote do
            try(unquote(contents))
          end
      end

    var = Macro.escape(var)
    contents = Macro.escape(contents, unquote: true)

    %{module: mod, file: file, line: line} = __CALLER__

    quote bind_quoted: [
            var: var,
            contents: contents,
            message: message,
            mod: mod,
            file: file,
            line: line
          ] do
      slug = Inngest.Function.register_step(mod, file, line, :step_sleep, message, execute: true)

      def unquote(slug)(unquote(var)), do: unquote(contents)
    end
  end

  defmacro sleep(duration) do
    %{module: mod, file: file, line: line} = __CALLER__

    # Add differentiator for sleeps with potentially similar duration
    idx = Module.get_attribute(mod, :inngest_sleep_idx, 0)
    Module.put_attribute(mod, :inngest_sleep_idx, idx + 1)

    quote bind_quoted: [duration: duration, mod: mod, file: file, line: line, idx: idx] do
      slug = Inngest.Function.register_step(mod, file, line, :step_sleep, duration, idx: idx)
      def unquote(slug)(), do: nil
    end
  end

  defmacro wait_for_event(event_name, var \\ quote(do: _), contents) do
    unless is_tuple(var) do
      IO.warn(
        "step context is always a map. The pattern " <>
          "#{inspect(Macro.to_string(var))} will never match",
        Macro.Env.stacktrace(__CALLER__)
      )
    end

    contents =
      case contents do
        [do: block] ->
          quote do
            unquote(block)
          end

        _ ->
          quote do
            try(unquote(contents))
          end
      end

    var = Macro.escape(var)
    contents = Macro.escape(contents, unquote: true)

    %{module: mod, file: file, line: line} = __CALLER__

    quote bind_quoted: [
            var: var,
            contents: contents,
            event_name: event_name,
            mod: mod,
            file: file,
            line: line
          ] do
      slug = Inngest.Function.register_step(mod, file, line, :step_wait_for_event, event_name)

      def unquote(slug)(unquote(var)), do: unquote(contents)
    end
  end

  def register_step(mod, file, line, step_type, name, tags \\ []) do
    unless Module.has_attribute?(mod, :inngest_fn_steps) do
      raise "cannot define #{step_type}. Please make sure you have invoked " <>
              "\"use Inngest.Function\" in the current module"
    end

    opts =
      if step_type == :step_wait_for_event,
        do: tags |> normalize_tags(),
        else: %{}

    slug =
      case Keyword.get(tags, :idx) do
        nil -> validate_step_name("#{step_type} #{name}")
        idx -> validate_step_name("#{step_type} #{name} #{idx}")
      end

    if Module.defines?(mod, {slug, 1}) do
      raise ~s("#{slug}" is already defined in #{inspect(mod)})
    end

    tags =
      tags
      |> normalize_tags()
      |> validate_tags()
      |> Map.merge(%{
        file: file,
        line: line
      })

    fn_slug = Module.get_attribute(mod, :fn_slug)

    step = %Step{
      id: slug,
      name: name,
      step_type: step_type,
      opts: opts,
      tags: tags,
      mod: mod,
      runtime: %Step.RunTime{
        url: "#{Config.app_host()}/api/inngest/fnId=#{fn_slug}&step=#{slug}"
      },
      retries: %Step.Retry{}
    }

    Module.put_attribute(mod, :inngest_fn_steps, step)

    slug
  end

  defmacro __before_compile__(env) do
    steps =
      env.module
      |> Module.get_attribute(:inngest_fn_steps)
      |> Enum.reverse()
      |> Macro.escape()

    quote do
      def __handler__ do
        %Inngest.Function.Handler{
          file: __ENV__.file,
          mod: __MODULE__,
          steps: unquote(steps)
        }
      end
    end
  end

  def validate_datetime(datetime) when is_binary(datetime) do
    with {:error, _} <- Timex.parse(datetime, "{RFC3339}"),
         {:error, _} <- Timex.parse(datetime, "{YYYY}-{MM}-{DD}T{h24}:{mm}:{ss}"),
         {:error, _} <- Timex.parse(datetime, "{RFC1123}"),
         {:error, _} <- Timex.parse(datetime, "{RFC822}"),
         {:error, _} <- Timex.parse(datetime, "{RFC822z}"),
         # "Monday, 02-Jan-06 15:04:05 MST"
         {:error, _} <- Timex.parse(datetime, "{WDfull}, {D}-{Mshort}-{YY} {ISOtime} {Zname}"),
         # "Mon Jan 02 15:04:05 -0700 2006"
         {:error, _} <- Timex.parse(datetime, "{WDshort} {Mshort} {DD} {ISOtime} {Z} {YYYY}"),
         {:error, _} <- Timex.parse(datetime, "{UNIX}"),
         {:error, _} <- Timex.parse(datetime, "{ANSIC}"),
         # "Jan _2 15:04:05"
         # "Jan _2 15:04:05.000"
         {:error, _} <- Timex.parse(datetime, "{Mshort} {_D} {ISOtime}"),
         # {:error, _} <- Timex.parse(datetime, "{Mshort} {_D} {ISOtime}"),
         {:error, _} <- Timex.parse(datetime, "{ISOdate}") do
      {:error, "Unknown format for DateTime"}
    else
      {:ok, _val} ->
        {:ok, datetime}

      _ ->
        {:error, "Unknown result"}
    end
  end

  # TODO: Allow parsing DateTime, Date
  # def validate_datetime(%DateTime{} = datetime) do
  # end

  def validate_datetime(_), do: {:error, "Expect valid DateTime formatted input"}

  defp normalize_tags(tags) do
    tags
    |> Enum.reverse()
    |> Enum.reduce(%{}, fn
      {key, value}, acc -> Map.put(acc, key, value)
      tag, acc when is_atom(tag) -> Map.put(acc, tag, true)
      tag, acc when is_list(tag) -> Enum.into(tag, acc)
    end)
  end

  defp validate_tags(tags) do
    for tag <- @reserved, Map.has_key?(tags, tag) do
      raise "cannot set tag #{inspect(tag)} because it is reserved by Inngest.Function"
    end

    unless is_atom(tags[:step_type]) do
      raise("value for tag \":step_type\" must be an atom")
    end

    tags
  end

  defp validate_step_name(name) do
    try do
      name
      |> String.replace(~r/(\s|\:)+/, "_")
      |> String.downcase()
      |> String.to_atom()
    rescue
      SystemLimitError ->
        # credo:disable-for-next-line
        raise SystemLimitError, """
        the computed name of a step (which includes its type, \
        block if present, and the step name itself) must be shorter than 255 characters, \
        got: #{inspect(name)}
        """
    end
  end
end
