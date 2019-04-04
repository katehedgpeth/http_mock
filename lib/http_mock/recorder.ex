defmodule HTTPMock.Recorder do
  use GenServer
  alias HTTPoison.Response
  alias HTTPMock.Headers

  defmodule State do
    @enforce_keys [:file_name, :ets]
    defstruct [:file_name, :parent, :ets, tasks: %{}]
  end

  @type headers :: [{String.t(), String.t()}]

  @spec get(String.t(), headers, Keyword.t(), Keyword.t()) :: {:ok, Response.t()}
  def get(url, headers, params, opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    response = HTTPoison.get(url, headers, params)

    GenServer.cast(
      name,
      {:record, url: url, headers: headers, params: params, response: response}
    )

    response
  end

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def state(name) do
    GenServer.call(name, :state)
  end

  def file_path(%State{file_name: file_name}) do
    :http_mock
    |> Application.get_env(:record_folder)
    |> Path.join(file_name)
  end

  def init(opts) do
    file_name = Keyword.get(opts, :file_name, "http_mock_record.txt")
    parent = Keyword.get(opts, :parent)

    ets =
      opts
      |> Keyword.get(:name, __MODULE__)
      |> :ets.new([:public])

    {:ok, %State{file_name: file_name, parent: parent, ets: ets}}
  end

  def handle_call(:state, _from, %State{} = state) do
    {:reply, state, state}
  end

  def handle_cast({:record, data}, %State{} = state) do
    :ok = send_parent(state, {:record, data})
    %Task{ref: ref} = Task.async(__MODULE__, :add_to_ets, [state, data])
    {:noreply, %{state | tasks: Map.put(state.tasks, ref, :add_to_ets)}}
  end

  def handle_info({ref, {:add_to_ets, :ok}}, %State{} = state) do
    tasks =
      case Map.pop(state.tasks, ref) do
        {:add_to_ets, tasks} ->
          %Task{ref: ref} = Task.async(__MODULE__, :write_ets_to_file, [%{state | tasks: tasks}])

          Map.put(tasks, ref, :write_ets_to_file)

        {_, tasks} ->
          tasks
      end

    {:noreply, %{state | tasks: tasks}}
  end

  def handle_info({ref, {:write_ets_to_file, :ok}}, %State{} = state) do
    {_, tasks} = Map.pop(state.tasks, ref)
    state = %{state | tasks: tasks}
    send_parent(state, {:file_written, state})
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, _pid, :normal}, %State{} = state) do
    {:noreply, state}
  end

  def add_to_ets(%State{ets: ets}, url: url, headers: headers, params: params, response: response)
      when not is_nil(ets) do
    :ets.insert(ets, {url, Headers.clean(headers), params, response})
    {:add_to_ets, :ok}
    # rescue
    #   error -> {:add_to_ets, {:error, error}}
  end

  def write_ets_to_file(%State{} = state) do
    path =
      state
      |> file_path()
      |> String.to_charlist()

    :ets.tab2file(state.ets, path)

    {:write_ets_to_file, :ok}
  rescue
    error -> {:write_ets_to_file, {:error, error}}
  end

  def send_parent(%State{parent: pid}, msg) when is_pid(pid) do
    send(pid, msg)
    :ok
  end

  def send_parent(%State{}, _) do
    :ok
  end
end
