defmodule SlaxWeb.NotifyController do
  use SlaxWeb, :controller

  alias Slax.Accounts
  alias Slax.Accounts.PaymentHistories
  alias Slax.Transactions

  @api_token Application.compile_env(:slax, :api_keys)[:acoin]

  # def notify(conn, resp) when false <- hash_is_valid?(resp), do: send_resp(conn, 400, "Invalid hash")

  # def notify(conn, %{"transaction_id" => transaction_id})
  # when nil <- is_nil(Transactions.get_transactions_by_transaction_id(transaction_id)) do
  #   send_resp(conn, 409, "Duplicate notification ignored")
  # end

  def notify(conn, %{"error_code" => error_code, "message" => message, "success" => false}) do
    case error_code do
      5033 ->
        send_resp(conn, 400, "Not enough funds in user's account")
      _ ->
        send_resp(conn, 400, "Error: #{message} (Code: #{error_code})")
    end
  end

  def notify(conn,
    %{"transaction_id" => transaction_id,
    "amount" => amount,
    "currency" => currency,
    "status" => status,
    "merchant_reference" => merchant_reference} = response_argument) do

    with nil <- Transactions.get_transactions_by_transaction_id(transaction_id),
    true <- hash_is_valid?(response_argument) do

      IO.inspect(hash_is_valid?(response_argument), label: "hash_is_valid?")

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

          handle_subscription_update(conn, user, subscription_id, changeset)
        end
      end
    end

  def notify(conn, _params) do
    send_resp(conn, 400, "Bad Request")
  end

  defp handle_subscription_update(conn, user, subscription_id, changeset) do
    case Accounts.update_subscription_plan(user, subscription_id) do
      {:ok, _} -> save_notify(conn, changeset)
      {:error, _} -> send_resp(conn, 500, "Something went wrong.")
    end
  end

  def save_notify(conn, changeset) do
    case Transactions.save_transactions_history(changeset) do
      {:ok, _payment_history} ->
        send_resp(conn, 200, "OK")

      {:error, _changeset} ->
        send_resp(conn, 500, "Error saving payment history")
    end
  end

  def hash_is_valid?(%{"hash" => received_hash} = resp) do
    received_hash == generate_hash(resp)
  end

  def generate_hash(
    %{"transaction_id" => transaction_id,
      "amount" => amount,
      "currency" => currency,
      "status" => status,
      "merchant_reference" => merchant_reference}) do

      [_, token] = String.split(@api_token)

      IO.inspect([transaction_id, amount, currency, merchant_reference, status], label: "Arguments")
      data =
        [transaction_id, amount, currency, merchant_reference, status]
        |> Enum.reject(&is_nil_or_empty/1)
        |> Enum.join()
        |> Kernel.<>(token)
        |> String.downcase()

        IO.inspect(data, label: "Concatenated string")

      :crypto.hash(:sha512, data)
      |> Base.encode16(case: :lower)
  end

  defp is_nil_or_empty(value), do: value in [nil, ""]
end
