defmodule Inngest.NonRetriableError do
  defexception message: "Not retrying error. Exiting."
end
