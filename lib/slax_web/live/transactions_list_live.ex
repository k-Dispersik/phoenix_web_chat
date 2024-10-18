defmodule SlaxWeb.TransactionsListLive do
  use SlaxWeb, :live_view

  alias Slax.Transactions

  def render(assigns) do
    ~H"""
    <div class="w-full h-screen flex justify-center">
    <div class="w-full max-w-lg">
    <h1 class="text-2xl font-bold text-center mb-4">
    Payment History
    </h1>
     <button
        class="mb-4 btn btn-primary flex items-center text-green-700 border border-green-600 py-2 px-4 gap-2 rounded inline-flex items-center"
         onclick="history.back()">
         <.icon name="hero-backward" class="h-4 w-4" />
         Back
        </button>
        <.transactions_item
        :for={transaction <- @transactions_list}
        transaction={transaction}
        >
        </.transactions_item>
        </div>
    </div>
    """
  end

  def transactions_item(assigns) do
    ~H"""
    <br>
    <div class="space-y-4">
        <div class="bg-white-800 rounded-lg shadow-lg border-8">
          <input type="checkbox" class="hidden peer">
          <label class="block border-black p-4 cursor-pointer transition">
              <div class="flex justify-between">
              <%=  if @transaction.success do %>
                  <span class="text-green-700">Success</span>
              <% else %>
                  <span class="text-red-700">Fail</span>
              <% end %>
                  <span> <%= @transaction.amount %> <%= @transaction.currency %></span>
              </div>
          </label>
          <div class="bg-white-700 p-4">
              <hr class="border-t border-gray-300 my-4">
              <span><%=  @transaction.inserted_at |> Timex.format!("{0D}.{0M}.{YYYY}, {h24}:{m}") %></span>
              <p>Transaction ID: <%= @transaction.transaction_id %></p>
              <p>Status: <%= @transaction.status %></p>
          </div>
        </div>
    </div>
    """
  end


  def mount(_params, _session, socket) do
      transactions_list =
        socket.assigns.current_user.id
          |> Transactions.get_transactions_by_user()

    socket
      |> assign(:transactions_list, transactions_list)
      |> ok()
  end

end
