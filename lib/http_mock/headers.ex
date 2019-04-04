defmodule HTTPMock.Headers do
  require Logger

  def clean(headers) when is_list(headers) do
    :http_mock
    |> Application.get_env(:remove_headers, [])
    |> Enum.reduce(Map.new(headers), &remove_header/2)
    |> Enum.into([])
  end

  defp remove_header(header, header_map) do
    case Map.pop(header_map, header) do
      {nil, map} ->
        map

      {value, map} ->
        Logger.debug("module=#{__MODULE__} header=#{header} value=#{value} removed")
        map
    end
  end
end
