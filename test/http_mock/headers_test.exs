defmodule HTTPMock.HeadersTest do
  use ExUnit.Case, async: true
  alias HTTPMock.Headers

  setup do
    on_exit(fn ->
      Application.delete_env(:http_mock, :remove_headers)
    end)

    :ok
  end

  describe "clean/1" do
    @tag :capture_log
    test "removes headers that are specified in config" do
      Application.put_env(:http_mock, :remove_headers, ["x-api-key"])

      assert Headers.clean([{"x-api-key", "API_KEY"}]) == []
    end
  end
end
