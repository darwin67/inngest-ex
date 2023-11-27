defmodule Inngest.NonRetriableError do
  defexception message: "Not retrying error. Exiting."
end

defmodule Inngest.RetryAfterError do
  defexception [:message, seconds: 3]
end

defmodule Inngest.DebounceConfigError do
  defexception [:message]
end

defmodule Inngest.BatchEventConfigError do
  defexception [:message]
end

defmodule Inngest.RateLimitConfigError do
  defexception [:message]
end
