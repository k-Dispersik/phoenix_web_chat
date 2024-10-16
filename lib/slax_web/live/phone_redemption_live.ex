defmodule SlaxWeb.PhoneRedemptionLive do
  use SlaxWeb, :live_view

  alias Slax.Transactions
  alias Slax.Accounts.PaymentHistories
  alias Ecto.Changeset

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
          <div
          class="mt-8 w-full text-center text-2xl rounded-md py-3 px-5 font-lg text-green-700 shadow">
            R<%= @selected_price %>
          </div>
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
    |> assign(:pricing_plans, "monthly")
    |> assign(:show_modal, false)
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

  def handle_event("toggle-plans", _params, socket) do
    cond do
      socket.assigns.pricing_plans == "monthly" ->
        {:noreply, assign(socket, pricing_plans: "yearly")}

      socket.assigns.pricing_plans == "yearly" ->
          {:noreply, assign(socket, pricing_plans: "monthly")}
    end
  end

  def handle_event("validate-redemption-phone", %{"phone_form" => %{"phone_number" => phone_number}}, socket) do
    changeset = PaymentHistories.changeset(%PaymentHistories{}, %{"phone_number" => phone_number})

    socket
    |> assign_form(changeset)
    |> noreply()
  end

  def handle_event("submit-redemption", %{"phone_form" => %{"phone_number" => phone_number}}, socket) do
    amount = socket.assigns.selected_price

    case Transactions.create(phone_number, amount, socket.assings.current_user.username) do
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

  def handle_event("buy-click", %{"value" => value}, socket) do
    selected_price = get_selected_price(socket.assigns.pricing_plans, value)

    socket
      |> assign(:show_modal, true)
      |> assign(:selected_price, selected_price)
      |> noreply()
  end

  defp get_selected_price(plans, level) do
    price_list()[plans][level]
  end

  # Temporary function for subscription price list.
  # This function will likely be replaced by a database-driven solution in the future.
  defp price_list() do
    %{
      "monthly" => %{
        "standard" => 5,
        "advanced" => 9
      },
      "yearly" => %{
        "standard" => 60,
        "advanced" => 100
      }
    }
  end

end
