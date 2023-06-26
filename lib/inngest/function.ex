defmodule Inngest.Function do
  @moduledoc """
  Module to be used within user code to setup an Inngest function.
  Making it servable and invokable.
  """
  alias Inngest.Function.{Args, Step, Trigger}

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

  @doc """
  The user provided logic that will be invoked
  """
  @callback perform(Args.t()) :: {:ok, any()} | {:error, any()}

  @reserved [:step]

  defmacro __using__(opts) do
    quote location: :keep do
      unless Inngest.Function.__register__(__MODULE__, unquote(opts)) do
        # placeholder
      end

      alias Inngest.Function.Trigger
      # import Inngest.Function, only: [step: 2, step: 3]
      import Inngest.Function
      @before_compile unquote(__MODULE__)

      @behaviour Inngest.Function

      @opts unquote(opts)

      @impl true
      def slug() do
        # TOOD: Use app name as prefix
        if Keyword.get(@opts, :id),
          do: Keyword.get(@opts, :id),
          else:
            Keyword.get(@opts, :name)
            |> String.replace(~r/[\.\/\s]+/, "-")
            |> String.downcase()
      end

      @impl true
      def name(), do: Keyword.get(@opts, :name)

      @impl true
      def trigger(), do: @opts |> Map.new() |> trigger()
      defp trigger(%{event: event} = _opts), do: %Trigger{event: event}
      defp trigger(%{cron: cron} = _opts), do: %Trigger{cron: cron}

      def steps(),
        do: %{
          "step" => %{
            id: "step",
            name: "step",
            runtime: %{
              type: "http",
              url: "http://127.0.0.1:4000/api/inngest?fnId=#{slug()}&step=step"
            },
            retries: %{
              attempts: 3
            }
          }
        }

      def serve() do
        %{
          id: slug(),
          name: name(),
          triggers: [trigger()],
          steps: steps(),
          mod: __MODULE__
        }
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
            # :ok
          end

        _ ->
          quote do
            try(unquote(contents))
            # :ok
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
      slug = Inngest.Function.register_step(mod, file, line, :step_run, message, [])

      def unquote(slug)(unquote(var)), do: unquote(contents)
    end
  end

  def register_step(mod, file, line, step_type, name, tags) do
    unless Module.has_attribute?(mod, :inngest_fn_steps) do
      raise "cannot define #{step_type}. Please make sure you have invoked " <>
              "\"use Inngest.Function\" in the current module"
    end

    slug = validate_step_name("#{step_type} #{name}")

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

    step = %Step{name: name, slug: slug, step_type: step_type, tags: tags, mod: mod}
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
      def __inngest__ do
        %Inngest.Function.Handler{
          file: __ENV__.file,
          name: __MODULE__,
          steps: unquote(steps)
        }
      end
    end
  end

  defp normalize_tags(tags) do
    Enum.reduce(Enum.reverse(tags), %{}, fn
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
      |> String.replace(~r/\s+/, "_")
      |> String.to_atom()
    rescue
      SystemLimitError ->
        raise SystemLimitError, """
        the computed name of a step (which includes its type, \
        block if present, and the step name itself) must be shorter than 255 characters, \
        got: #{inspect(name)}
        """
    end
  end
end
