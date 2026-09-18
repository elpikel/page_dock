defmodule PageDock.Encrypted.Binary do
  @moduledoc """
  Ecto type that transparently encrypts/decrypts a string field via
  `PageDock.Vault`. Backed by a `:binary` (bytea) column.
  """
  use Cloak.Ecto.Binary, vault: PageDock.Vault
end
