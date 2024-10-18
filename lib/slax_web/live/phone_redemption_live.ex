defmodule SlaxWeb.PhoneRedemptionLive do
  use SlaxWeb, :live_view

  alias Slax.Repo
  alias Slax.Transactions
  alias Slax.Accounts.PaymentHistories
  alias Ecto.Changeset
  alias Slax.Subscription

  def redemption_form(assigns) do
    ~H"""
    <div class="flex items-center justify-center">
      <div class="w-1/2">
        <.simple_form
          for={@form}
          id="redemption_form"
          phx-change="validate-redemption-phone"
          phx-submit="submit-redemption"
        >
          <h2 class="text-center">Payment for subscription</h2>
          <.input field={@form[:phone_number]} type="text" label="Phone number" />
          <:actions>
            <.button class="w-full text-4xl">Pay</.button>
          </:actions>
        </.simple_form>
      </div>
    </div>
    """
  end


  def mount(_params, _session, socket) do

    changeset = phone_changeset(%{})

    {:ok,
    socket
    |> assign_form(changeset)
    |> assign(:price_list, price_list())
    |> assign(:sub_level, "basic")
    |> assign(:billing_cycle, "monthly")
    |> assign(:selected_price, nil)}

  end

  defp assign_form(socket, changeset) do
    assign(socket, :form, to_form(changeset, as: :phone_form))
  end

  defp phone_changeset(attrs) do
    {%{}, %{phone_number: :string}}
    |> Changeset.cast(attrs, [:phone_number])
    |> Changeset.validate_required([:phone_number])
    |> Changeset.validate_format(:phone_number, ~r/^27\d{9}$/, message: "Phone number must start with '27' and be 11 digits long")
  end

  def handle_params(_params, _session, socket) do
    noreply(socket)
  end

  def handle_event("toggle-plans", %{"plan" => plan}, socket) do
    socket
      |> assign(:billing_cycle, plan)
      |> noreply()
  end

  def handle_event("validate-redemption-phone", %{"phone_form" => %{"phone_number" => phone_number}}, socket) do
    changeset = PaymentHistories.changeset(%PaymentHistories{}, %{"phone_number" => phone_number})

    socket
    |> assign_form(changeset)
    |> noreply()
  end

  def handle_event("submit-redemption", %{"phone_form" => %{"phone_number" => phone_number}}, socket) do
    sub_level = socket.assigns.sub_level
    billing_cycle = socket.assigns.billing_cycle
    selected_price = socket.assigns.selected_price

    amount = Decimal.to_integer(selected_price) * 100

    sub =
      Repo.get_by(Subscription, name: sub_level, billing_cycle: billing_cycle)

    merchant_reference = "#{socket.assigns.current_user.username}|#{sub.id}"

    case Transactions.create(phone_number, amount, merchant_reference) do
      {:ok, %{"redirect_url" => redirect_url}} ->
        socket
        |> put_flash(:info, "Redirecting...")
        |> redirect(external: redirect_url)
        |> noreply()

      {:error, status_code, body} ->
        IO.inspect(body, label: "Body")

         socket
         |> put_flash(:error, "Payment failed: #{status_code}")
         |> noreply()
    end
  end

  def handle_event("buy-click", %{"sub_level" => sub_level}, socket) do
    billing_cycle = socket.assigns.billing_cycle
    IO.inspect(socket.assigns.billing_cycle)
    socket
      |> assign(:selected_price, socket.assigns.price_list[billing_cycle][sub_level])
      |> assign(:sub_level, sub_level)
      |> noreply()
  end

  def price_list() do
    subscriptions = Repo.all(Subscription)

    Enum.reduce(subscriptions, %{}, fn subscription, acc ->
      cycle = subscription.billing_cycle
      name = subscription.name
      price = subscription.price

      Map.update(acc, cycle, %{name => price}, fn current ->
        Map.put(current, name, price)
      end)
    end)
  end

end
