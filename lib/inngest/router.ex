defmodule Inngest.Router do
  @moduledoc """
  Router module for Inngest to be integrated with apps that
  have a router.

  Currently assuming Phonenix as the main option
  """

  def plug do
    quote do
      use Inngest.Router.Plug
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
