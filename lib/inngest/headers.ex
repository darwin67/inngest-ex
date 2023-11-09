defmodule Inngest.Headers do
  def forwarded_for, do: "X-Forwarded-For"
  def framework, do: "X-Inngest-Framework"
  def no_retry, do: "X-Inngest-No-Retry"
  def sdk, do: "X-Inngest-SDK"
  def server_kind, do: "X-Inngest-Server-Kind"
  def server_timing, do: "Server-Timing"
end
