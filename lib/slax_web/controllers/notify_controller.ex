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
    [username, subscription_id] = String.split(merchant_reference, "|")

    case Accounts.get_user_by_username(username) do
      nil ->
        send_resp(conn, 404, "User not found")

      user ->
        amount = amount |> Integer.to_string() |> Decimal.new() |> Decimal.div(100)

        changeset = PaymentHistories.changeset(%PaymentHistories{}, %{
          transaction_id: transaction_id,
          amount: amount,
          currency: currency,
          status: status,
          success: status == "complete",
          user_id: user.id
        })

        case Accounts.update_subscrabtion_plan(user.id, subscription_id) do
          {:ok, _} -> save_notify(conn, changeset)
          {:error, _} -> send_resp(conn, 500, "Something went wrong.")
        end
    end
  end

  def notify(conn, _params) do
    send_resp(conn, 400, "Bad Request")
  end

  def save_notify(conn, changeset) do
    case Transactions.save_transactions_history(changeset) do
      {:ok, _payment_history} ->
        send_resp(conn, 200, "OK")

      {:error, _changeset} ->
        send_resp(conn, 500, "Error saving payment history")
    end
  end
end
