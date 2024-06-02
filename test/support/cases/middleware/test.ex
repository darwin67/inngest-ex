defmodule Inngest.Test.Case.Middleware.Test do
  @moduledoc false

  @behaviour Inngest.Middleware

  @impl true
  def init(_), do: []

  @impl true
  def name(), do: "test"

  @impl true
  def transform_input(input_args, _opts) do
    IO.inspect("Transform input")
    input_args
  end

  @impl true
  def transform_output(output_args, _opts) do
    IO.inspect("Transform outputx")
    output_args
  end

  @impl true
  def before_memoization(_opts) do
    IO.inspect("Before memoization")
    :ok
  end

  @impl true
  def after_memoization(_opts) do
    IO.inspect("After memoization")
    :ok
  end

  @impl true
  def before_execution(_opts) do
    IO.inspect("Before execution")
    :ok
  end

  @impl true
  def after_execution(_opts) do
    IO.inspect("After execution")
    :ok
  end
end
