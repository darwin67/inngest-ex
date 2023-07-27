defmodule Inngest.Router do
  @moduledoc """
  Router module for Inngest to be integrated with apps that
  have a router.

  Currently available options are
  - `Phoenix`
  - `Plug.Router`

  ## Examples
      use Inngest.Router, :phoenix
      use Inngest.Router, :plug
  """

  def plug do
    quote do
      use Inngest.Router.Plug
    end
  end

  def phoenix do
    quote do
      use Inngest.Router.Phoenix
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
