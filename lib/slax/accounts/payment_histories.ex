defmodule Slax.Accounts.PaymentHistories do
  use Ecto.Schema

  alias Slax.Accounts.User

  import Ecto.Changeset


  schema "payment_histories" do

    field :transaction_id, :string
    field :amount, :decimal
    field :currency, :string
    field :status, :string
    field :success, :boolean

    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(payment_history, attrs) do
    payment_history
    |> cast(attrs, [:transaction_id, :amount, :currency, :status, :success])
    |> validate_required([:transaction_id, :amount, :currency, :status, :success])
    |> validate_number(:amount, greater_than: 0)
    |> validate_length(:currency, is: 3)
  end

end
