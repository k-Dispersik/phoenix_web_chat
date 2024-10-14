defmodule Slax.Repo.Migrations.CreatePaymentHistories do
  use Ecto.Migration

  def change do
    create table(:payment_histories) do
      add :transaction_id, :string, null: false
      add :amount, :decimal, precision: 10, scale: 2, null: false
      add :currency, :string, size: 3, null: false
      add :status, :string, null: false
      add :success, :boolean, null: false

      add :user_id, references(:users, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create index(:payment_histories, [:transaction_id])
  end
end
