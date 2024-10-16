defmodule SlaxWeb.NotifyController do
  use SlaxWeb, :controller

  alias Slax.Accounts
  alias Slax.Accounts.PaymentHistories
  alias Slax.Transactions

  def notify(conn,
    %{"transaction_id" => transaction_id,
     "amount" => amount,
     "currency" => currency,
     "status" => status,
     "merchant_reference" => merchant_reference}) do

    # IO.inspect(%{transaction_id: transaction_id, amount: amount, currency: currency, status: status, merchant_reference: merchant_reference}, label: "Received notification")

    case Accounts.get_user_by_username(merchant_reference) do
      nil ->
        send_resp(conn, 404, "User not found")

      user ->
        changeset = PaymentHistories.changeset(%PaymentHistories{}, %{
          transaction_id: transaction_id,
          amount: Decimal.new(amount),
          currency: currency,
          status: status,
          success: status == "complete",
          user_id: user.id
        })

        case Transactions.save_transactions_history(changeset) do
          {:ok, _payment_history} ->
            send_resp(conn, 200, "OK")

          {:error, _changeset} ->
            send_resp(conn, 500, "Error saving payment history")
        end
    end
  end

  def notify(conn, _params) do
    send_resp(conn, 400, "Bad Request")
  end
end
