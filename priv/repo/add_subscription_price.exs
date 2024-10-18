alias Slax.Repo
alias Slax.Accounts.Subscription

Repo.insert!(%Subscription{name: "basic", billing_cycle: "monthly", price: 5, duration: 30})
Repo.insert!(%Subscription{name: "advanced", billing_cycle: "monthly", price: 10, duration: 30})
Repo.insert!(%Subscription{name: "basic", billing_cycle: "yearly", price: 40, duration: 365})
Repo.insert!(%Subscription{name: "advanced", billing_cycle: "yearly", price: 90, duration: 365})
