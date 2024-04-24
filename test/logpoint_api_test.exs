defmodule LogpointApiTest do
  use ExUnit.Case
  doctest LogpointApi

  test "greets the world" do
    assert LogpointApi.hello() == :world
  end
end
