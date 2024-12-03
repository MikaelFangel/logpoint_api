defmodule Logpoint.Api.Test do
  use ExUnit.Case

  setup do
    {:ok, supervisor} = Logpoint.start_supervisor()
    {:ok, supervisor: supervisor}
  end

  test "client restarts on crash", %{supervisor: supervisor} do
    {:ok, pid} = Logpoint.new("127.0.0.1", "user", "key")
    assert Process.alive?(pid)

    Process.exit(pid, :kill)
    :timer.sleep(100)

    children = DynamicSupervisor.count_children(supervisor)
    assert children.active == 1
  end

  test "client stops nicely on terminate_child", %{supervisor: supervisor} do
    {:ok, pid} = Logpoint.new("127.0.0.1", "user", "key")
    assert Process.alive?(pid)

    Logpoint.stop(pid)

    children = DynamicSupervisor.count_children(supervisor)
    assert children.active == 0
  end

  test "starts multiple children", %{supervisor: supervisor} do
    {:ok, pid1} = Logpoint.new("127.0.0.1", "user", "key")
    {:ok, pid2} = Logpoint.new("127.0.0.1", "user", "key")
    assert Process.alive?(pid1)
    assert Process.alive?(pid2)

    children = DynamicSupervisor.count_children(supervisor)
    assert children.active == 2
  end
end
