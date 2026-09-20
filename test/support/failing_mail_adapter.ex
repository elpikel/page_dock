defmodule PageDock.FailingMailAdapter do
  @moduledoc """
  A Swoosh adapter that always fails, for testing delivery-error handling.
  """
  @behaviour Swoosh.Adapter

  @impl true
  def deliver(_email, _config), do: {:error, :simulated_delivery_failure}

  @impl true
  def validate_config(_config), do: :ok
end
