defmodule HTTPMockTest do
  use ExUnit.Case

  alias HTTPMock.{
    NotFoundError,
    Recorder
  }

  doctest HTTPMock

  setup_all do
    record_folder = Application.app_dir(:http_mock, "priv")
    File.mkdir_p(record_folder)
    Application.put_env(:http_mock, :record_folder, record_folder)

    on_exit(fn ->
      Application.delete_env(:http_mock, :record_folder)
    end)
  end

  setup tags do
    name = :"httpmock_test_#{tags.line}"
    file_name = "#{name}.txt"
    recorder_name = :"httpmock_test_#{tags.line}_recorder"

    {:ok, name: name, file_name: file_name, recorder_name: recorder_name}
  end

  describe "get/1" do
    test "fetches a recorded response", %{
      name: name,
      file_name: file_name,
      recorder_name: recorder_name
    } do
      url = "http://www.google.com"

      {:ok, recorder_pid} =
        Recorder.start_link(name: recorder_name, file_name: file_name, parent: self())

      file_path =
        recorder_name
        |> Recorder.state()
        |> Recorder.file_path()

      {:ok, %HTTPoison.Response{} = expected} = Recorder.get(url, [], [], name: recorder_pid)
      wait_for_write()

      {:ok, _httpmock_pid} = HTTPMock.start_link(name: name, file_name: file_name, parent: self())

      on_exit(fn -> File.rm(file_path) end)

      response = HTTPMock.get(url, [], [], name: name)
      assert_receive {:get, url: ^url, headers: [], params: []}

      assert response == {:ok, expected}
    end

    test "raises an error if no match is found for request", %{
      name: name,
      file_name: file_name,
      recorder_name: recorder_name
    } do
      url = "http://www.google.com"

      {:ok, recorder_pid} =
        Recorder.start_link(name: recorder_name, file_name: file_name, parent: self())

      file_path =
        recorder_name
        |> Recorder.state()
        |> Recorder.file_path()

      {:ok, %HTTPoison.Response{}} = Recorder.get(url, [], [], name: recorder_pid)
      wait_for_write()

      {:ok, _httpmock_pid} = HTTPMock.start_link(name: name, file_name: file_name, parent: self())

      on_exit(fn -> File.rm(file_path) end)

      ExUnit.Assertions.assert_raise(
        NotFoundError,
        fn -> HTTPMock.get("http://www.yahoo.com", [], [], name: name) end
      )
    end

    test "records if :record? config is set to true", %{
      name: name,
      recorder_name: recorder_name,
      file_name: file_name
    } do
      url = "http://www.google.com"

      {:ok, recorder_pid} =
        Recorder.start_link(name: recorder_name, file_name: file_name, parent: self())

      {:ok, %HTTPoison.Response{}} = Recorder.get(url, [], [], name: recorder_pid)
      wait_for_write()

      file_path =
        recorder_name
        |> Recorder.state()
        |> Recorder.file_path()

      on_exit(fn ->
        Application.put_env(:http_mock, :record?, false)
        File.rm(file_path)
      end)

      {:ok, _} = HTTPMock.start_link(name: name, file_name: file_name, parent: self())

      Application.put_env(:http_mock, :record?, true)

      assert {:ok, %HTTPoison.Response{} = response} =
               HTTPMock.get("http://www.yahoo.com", [], [], name: recorder_name)

      assert_receive {:record,
                      url: "http://www.yahoo.com",
                      headers: [],
                      params: [],
                      response: {:ok, ^response}}
    end
  end

  def wait_for_write do
    receive do
      {:file_written, %Recorder.State{}} -> :ok
    end
  end
end
