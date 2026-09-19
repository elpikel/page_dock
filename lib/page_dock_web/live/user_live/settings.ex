defmodule PageDockWeb.UserLive.Settings do
  use PageDockWeb, :live_view

  on_mount {PageDockWeb.UserAuth, :require_sudo_mode}

  alias PageDock.Accounts
  alias PageDock.Github

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.dashboard
      flash={@flash}
      current_scope={@current_scope}
      active={:settings}
      title="Settings"
    >
      <div class="max-w-[720px] grid gap-4">
        <div class="card p-6 md:p-8">
          <h2 class="text-[15px] font-medium text-text mb-4">GitHub</h2>
          <%= if @github_account do %>
            <div class="flex items-center justify-between gap-4" id="github-connected">
              <div class="flex items-center gap-3 min-w-0">
                <img
                  :if={@github_account.avatar_url}
                  src={@github_account.avatar_url}
                  alt=""
                  class="w-9 h-9 rounded-full border border-border"
                />
                <div class="min-w-0">
                  <p class="text-text font-medium truncate">@{@github_account.login}</p>
                  <p class="text-[13px] text-muted">Connected · repo, webhooks</p>
                </div>
              </div>
              <.link
                href={~p"/auth/github"}
                method="delete"
                data-confirm="Disconnect this GitHub account?"
                class="btn-secondary h-9 px-3 no-underline shrink-0"
                id="github-disconnect"
              >
                Disconnect
              </.link>
            </div>
          <% else %>
            <div class="flex items-center justify-between gap-4">
              <p class="text-[14px] text-muted">
                Connect GitHub to link a repository and deploy on every push.
              </p>
              <a
                href={~p"/auth/github"}
                class="btn-primary h-9 px-3 no-underline shrink-0 inline-flex items-center gap-2"
                id="github-connect"
              >
                <.icon name="hero-link" class="size-4" /> Connect GitHub
              </a>
            </div>
          <% end %>
        </div>

        <div class="card p-6 md:p-8">
          <h2 class="text-[15px] font-medium text-text mb-4">Email address</h2>
          <.form
            for={@email_form}
            id="email_form"
            phx-submit="update_email"
            phx-change="validate_email"
          >
            <.input
              field={@email_form[:email]}
              type="email"
              label="Email"
              autocomplete="username"
              spellcheck="false"
              required
            />
            <.button class="btn-primary mt-4" phx-disable-with="Changing...">Change email</.button>
          </.form>
        </div>

        <div class="card p-6 md:p-8">
          <h2 class="text-[15px] font-medium text-text mb-4">Password</h2>
          <.form
            for={@password_form}
            id="password_form"
            action={~p"/users/update-password"}
            method="post"
            phx-change="validate_password"
            phx-submit="update_password"
            phx-trigger-action={@trigger_submit}
          >
            <input
              name={@password_form[:email].name}
              type="hidden"
              id="hidden_user_email"
              spellcheck="false"
              value={@current_email}
            />
            <.input
              field={@password_form[:password]}
              type="password"
              label="New password"
              autocomplete="new-password"
              spellcheck="false"
              required
            />
            <.input
              field={@password_form[:password_confirmation]}
              type="password"
              label="Confirm new password"
              autocomplete="new-password"
              spellcheck="false"
            />
            <.button class="btn-primary mt-4" phx-disable-with="Saving...">
              Save password
            </.button>
          </.form>
        </div>
      </div>
    </Layouts.dashboard>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    socket =
      case Accounts.update_user_email(socket.assigns.current_scope.user, token) do
        {:ok, _user} ->
          put_flash(socket, :info, "Email changed successfully.")

        {:error, _} ->
          put_flash(socket, :error, "Email change link is invalid or it has expired.")
      end

    {:ok, push_navigate(socket, to: ~p"/users/settings")}
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    email_changeset = Accounts.change_user_email(user, %{}, validate_unique: false)
    password_changeset = Accounts.change_user_password(user, %{}, hash_password: false)

    socket =
      socket
      |> assign(:current_email, user.email)
      |> assign(:github_account, Github.get_connected_account(socket.assigns.current_scope))
      |> assign(:email_form, to_form(email_changeset))
      |> assign(:password_form, to_form(password_changeset))
      |> assign(:trigger_submit, false)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate_email", params, socket) do
    %{"user" => user_params} = params

    email_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_email(user_params, validate_unique: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, email_form: email_form)}
  end

  def handle_event("update_email", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)

    case Accounts.change_user_email(user, user_params) do
      %{valid?: true} = changeset ->
        Accounts.deliver_user_update_email_instructions(
          Ecto.Changeset.apply_action!(changeset, :insert),
          user.email,
          &url(~p"/users/settings/confirm-email/#{&1}")
        )

        info = "A link to confirm your email change has been sent to the new address."
        {:noreply, socket |> put_flash(:info, info)}

      changeset ->
        {:noreply, assign(socket, :email_form, to_form(changeset, action: :insert))}
    end
  end

  def handle_event("validate_password", params, socket) do
    %{"user" => user_params} = params

    password_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_password(user_params, hash_password: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form)}
  end

  def handle_event("update_password", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)

    case Accounts.change_user_password(user, user_params) do
      %{valid?: true} = changeset ->
        {:noreply, assign(socket, trigger_submit: true, password_form: to_form(changeset))}

      changeset ->
        {:noreply, assign(socket, password_form: to_form(changeset, action: :insert))}
    end
  end
end
