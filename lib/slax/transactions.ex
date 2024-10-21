defmodule Slax.Transactions do

  alias Slax.Accounts.{User, PaymentHistories}
  alias Slax.Repo

  @api_token Application.compile_env(:slax, :api_keys)[:acoin]
  @url_prefix "https://f547-212-92-239-219.ngrok-free.app"

  def create(phone_number, amount, merchant_reference) do
    headers = [
      {"Authorization", @api_token},
      {"Content-Type", "application/json"}
    ]

    endpoint_url = "https://stage.acoin.co.za/api/v1/phone-redemptions"

    body = %{
      "phone_number" => phone_number,
      "amount" => amount,
      "merchant_reference" => merchant_reference,
      "notify_url" => @url_prefix <> "/api/transactions/notify",
      "cancel_url" => @url_prefix <> "/transactions/status",
      "error_url" => @url_prefix <> "/transactions/status",
      "success_url" => @url_prefix <> "/transactions/status"
    }

    case Jason.encode(body) do
      {:ok, json_body} ->

        request = Finch.build(:post, endpoint_url, headers, json_body)
        send_request(request)

      {:error, _reason} ->
        {:error, :invalid_json}
    end
  end

  def send_request(request) do
    case Finch.request(request, Slax.Finch) do
      {:ok, %Finch.Response{status: 201, body: body}} ->
        {:ok, Jason.decode!(body)}

      {:ok, %Finch.Response{status: status_code, body: body}} ->
        {:error, status_code, Jason.decode!(body)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def get_transactions_by_user(user_id) do
    Repo.get(User, user_id) |> Repo.preload(:payment_histories) |> Map.get(:payment_histories, [])
  end

  def save_transactions_history(changeset) do
    Repo.insert(changeset)
  end

  def get_transactions_by_transaction_id(transaction_id) do
    Repo.get_by(PaymentHistories, transaction_id: transaction_id)
  end
end
