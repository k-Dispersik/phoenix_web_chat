defmodule Slax.Repo.Migrations.CreateSubscriptios do
  use Ecto.Migration

  def change do
    create table(:subscriptions) do
      add :name, :string
      add :price, :decimal, precision: 10, scale: 2
      add :billing_cycle, :string # "monthly" or "yearly"
      add :duration, :integer

      timestamps(type: :utc_datetime)
    end
  end
end
