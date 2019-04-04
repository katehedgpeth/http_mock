defmodule HTTPMock do
  use GenServer
  alias HTTPMock.Headers

  @moduledoc """
  Documentation for HTTPMock.
  """

  defmodule State do
    @enforce_keys [:ets]
    defstruct [:ets, :parent]
  end

  defmodule NotFoundError do
    defexception [:message, :url, :headers, :params]
  end

  @doc """
  Hello world.
  """
  def get(url, headers, params, opts \\ []) when is_list(opts) do
    opts
    |> Keyword.get(:name, __MODULE__)
    |> GenServer.call({:get, url: url, headers: headers, params: params})
    |> case do
      {:ok, %HTTPoison.Response{}} = response -> response
      {:error, %HTTPoison.Error{}} = error -> error
      {:error, %NotFoundError{} = error} -> raise error
    end
  end

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def init(opts) do
    {:ok, ets} =
      opts
      |> file_path()
      |> String.to_charlist()
      |> :ets.file2tab()

    {:ok, %State{ets: ets, parent: Keyword.get(opts, :parent)}}
  end

  def file_path(opts) do
    file_name =
      Keyword.get_lazy(opts, :file_name, fn -> Application.fetch_env!(:http_mock, :file_name) end)

    :http_mock
    |> Application.fetch_env!(:record_folder)
    |> Path.join(file_name)
  end

  def handle_call(:state, _from, %State{} = state) do
    {:reply, state, state}
  end

  def handle_call({:get, url: url, headers: headers, params: params}, _from, %State{} = state) do
    :ok = send_parent(state, {:get, url: url, headers: headers, params: params})

    response =
      case :ets.select(state.ets, [{{url, Headers.clean(headers), params, :"$1"}, [], [:"$1"]}]) do
        [response] ->
          response

        [] ->
          {:error,
           %NotFoundError{
             message: "mock not found for request",
             url: url,
             headers: headers,
             params: params
           }}
      end

    {:reply, response, state}
  end

  def send_parent(%State{parent: parent}, msg) when not is_nil(parent) do
    send(parent, msg)
    :ok
  end

  def send_parent(%State{}, _) do
    :ok
  end
end
