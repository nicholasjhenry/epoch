# Compile test support modules
Code.require_file("epoch/event_store/support/test_events.ex", __DIR__)

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Epoch.Repo, :manual)
