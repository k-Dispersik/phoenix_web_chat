defmodule Slax.Subscription do
  use Ecto.Schema
  import Ecto.Changeset

  schema "subscriptions" do
    field :name, :string
    field :price, :decimal
    field :billing_cycle, :string
    field :duration, :integer

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(subscription, attrs) do
    subscription
    |> cast(attrs, [:name, :price, :billing_cycle, :duration])
    |> validate_required([:name, :price, :billing_cycle, :duration])
  end
end
