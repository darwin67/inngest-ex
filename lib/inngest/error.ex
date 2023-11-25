defmodule Inngest.NonRetriableError do
  defexception message: "Not retrying error. Exiting."
end

defmodule Inngest.RetryAfterError do
  defexception [:message, seconds: 3]
end

defmodule Inngest.InvalidDebounceConfigError do
  defexception message: "a 'period' must be set for debounce"
end
