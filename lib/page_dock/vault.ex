defmodule PageDock.Vault do
  @moduledoc """
  Cloak vault used to encrypt sensitive fields at rest (e.g. GitHub OAuth
  tokens). Ciphers/keys are configured in `config/runtime.exs`.
  """
  use Cloak.Vault, otp_app: :page_dock
end
