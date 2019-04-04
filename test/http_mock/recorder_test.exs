defmodule HTTPMock.RecorderTest do
  use ExUnit.Case, async: true
  alias HTTPMock.Recorder

  setup_all do
    record_folder = Application.app_dir(:http_mock, "priv")
    File.mkdir_p(record_folder)
    Application.put_env(:http_mock, :record_folder, record_folder)
  end

  setup tags do
    name = :"recorder_test_#{tags.line}"
    file_name = "#{name}.txt"
    {:ok, pid} = Recorder.start_link(name: name, file_name: file_name, parent: self())
    file_path =
    name
    |> Recorder.state()
    |> Recorder.file_path()
    File.rm(file_path)

    on_exit(fn ->
      File.rm(file_path)
    end)

    {:ok, name: name, pid: pid}
  end

  describe "get/3" do
    test "records responses and writes to file", %{name: name} do
      url = "http://www.google.com"
      assert {:ok, response} = Recorder.get(url, [], [], name: name)
      assert %HTTPoison.Response{} = response
      assert response.status_code == 200

      file_path =
        name
        |> Recorder.state()
        |> Recorder.file_path()

      refute File.exists?(file_path)

      assert_received {:record, data}

      assert Keyword.get(data, :url) == url

      assert_receive {:file_written, state}

      assert File.exists?(file_path)

      assert {:ok, ets} =
               state
               |> Recorder.file_path()
               |> String.to_charlist()
               |> :ets.file2tab()

      assert :ets.select(ets, [{{url, :_, :_, :"$1"}, [], [:"$1"]}]) == [{:ok, response}]
    end
  end
end
