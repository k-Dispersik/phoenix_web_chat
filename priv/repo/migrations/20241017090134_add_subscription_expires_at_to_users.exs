defmodule Slax.Repo.Migrations.AddSubscriptionExpiresAtToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :subscription_expires_at, :utc_datetime
    end
  end
end
