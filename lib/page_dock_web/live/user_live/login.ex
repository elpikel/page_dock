defmodule PageDockWeb.UserLive.Login do
  use PageDockWeb, :live_view

  alias PageDock.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="card p-6 md:p-8 space-y-6">
        <div>
          <h1 class="text-xl font-medium tracking-[-0.02em] text-text">Log in</h1>
          <p class="mt-1 text-[14px] text-muted">
            <%= if @current_scope do %>
              You need to reauthenticate to perform sensitive actions on your account.
            <% else %>
              Don't have an account? <.link
                navigate={~p"/users/register"}
                class="text-accent font-medium hover:underline"
                phx-no-format
              >Sign up</.link> for one now.
            <% end %>
          </p>
        </div>

        <div
          :if={local_mail_adapter?()}
          class="flex items-start gap-3 rounded-lg border border-border bg-raised px-4 py-3 text-[13px] text-muted"
        >
          <.icon name="hero-information-circle" class="size-5 shrink-0 text-accent" />
          <div>
            <p class="text-text">You are running the local mail adapter.</p>
            <p>
              To see sent emails, visit <.link href="/dev/mailbox" class="text-accent hover:underline">the mailbox page</.link>.
            </p>
          </div>
        </div>

        <.form
          :let={f}
          for={@form}
          id="login_form_magic"
          action={~p"/users/log-in"}
          phx-submit="submit_magic"
        >
          <.input
            readonly={!!@current_scope}
            field={f[:email]}
            type="email"
            label="Email"
            autocomplete="username"
            spellcheck="false"
            required
            phx-mounted={JS.focus()}
          />
          <.button class="btn-primary w-full mt-4">
            Log in with email <span aria-hidden="true">→</span>
          </.button>
        </.form>

        <div class="flex items-center gap-4 text-[13px] text-faint">
          <div class="h-px flex-1 bg-border"></div>
          or
          <div class="h-px flex-1 bg-border"></div>
        </div>

        <.form
          :let={f}
          for={@form}
          id="login_form_password"
          action={~p"/users/log-in"}
          phx-submit="submit_password"
          phx-trigger-action={@trigger_submit}
        >
          <.input
            readonly={!!@current_scope}
            field={f[:email]}
            type="email"
            label="Email"
            autocomplete="username"
            spellcheck="false"
            required
          />
          <.input
            field={@form[:password]}
            type="password"
            label="Password"
            autocomplete="current-password"
            spellcheck="false"
          />
          <.button class="btn-primary w-full mt-4" name={@form[:remember_me].name} value="true">
            Log in and stay logged in <span aria-hidden="true">→</span>
          </.button>
          <.button class="btn-secondary w-full mt-2">
            Log in only this time
          </.button>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    email =
      Phoenix.Flash.get(socket.assigns.flash, :email) ||
        get_in(socket.assigns, [:current_scope, Access.key(:user), Access.key(:email)])

    form = to_form(%{"email" => email}, as: "user")

    {:ok, assign(socket, form: form, trigger_submit: false)}
  end

  @impl true
  def handle_event("submit_password", _params, socket) do
    {:noreply, assign(socket, :trigger_submit, true)}
  end

  def handle_event("submit_magic", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_login_instructions(
        user,
        &url(~p"/users/log-in/#{&1}")
      )
    end

    info =
      "If your email is in our system, you will receive instructions for logging in shortly."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> push_navigate(to: ~p"/users/log-in")}
  end

  defp local_mail_adapter? do
    Application.get_env(:page_dock, PageDock.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
