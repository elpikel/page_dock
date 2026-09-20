defmodule PageDockWeb.UserLive.RegistrationEmailFailureTest do
  # async: false — swaps the global mailer adapter for the duration of the test.
  use PageDockWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import PageDock.AccountsFixtures

  alias PageDock.Accounts

  setup do
    original = Application.get_env(:page_dock, PageDock.Mailer)
    Application.put_env(:page_dock, PageDock.Mailer, adapter: PageDock.FailingMailAdapter)
    on_exit(fn -> Application.put_env(:page_dock, PageDock.Mailer, original) end)
    :ok
  end

  test "rolls back the account (no crash) when the confirmation email can't be sent",
       %{conn: conn} do
    email = unique_user_email()
    {:ok, lv, _html} = live(conn, ~p"/users/register")

    result =
      lv
      |> form("#registration_form", user: %{email: email})
      |> render_submit()

    # The LiveView must not crash; it stays on the page with an error...
    assert result =~ "send your confirmation email"
    # ...and the half-created, unreachable account is rolled back so the address
    # can be reused / retried.
    refute Accounts.get_user_by_email(email)
  end
end
