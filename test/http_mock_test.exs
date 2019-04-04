defmodule HTTPMockTest do
  use ExUnit.Case
  doctest HttpMock

  test "greets the world" do
    assert HttpMock.hello() == :world
  end
end
