defmodule Magpie.CustomRecords do
  @moduledoc """
  Context for custom records
  """
  alias Magpie.CustomRecords.CustomRecord
  alias Magpie.Repo

  import Magpie.Helpers

  def create_or_update_custom_record(custom_record_params, custom_record \\ %CustomRecord{}) do
    upload = custom_record_params["record"]

    try do
      case convert_uploaded_data(upload) do
        {:error, :invalid_format} ->
          {:error, :invalid_format}

        {:ok, data} ->
          custom_record
          |> CustomRecord.changeset(%{
            name: custom_record_params["name"],
            record: data
          })
          |> Repo.insert()
      end
    rescue
      UndefinedFunctionError -> {:error, :no_file_selected}
      _ -> {:error, :parse_failure}
    end
  end

  def get_custom_record(id) do
    Repo.get(CustomRecord, id)
  end

  def get_custom_record!(id) do
    Repo.get!(CustomRecord, id)
  end

  def delete_custom_record!(%CustomRecord{} = custom_record) do
    Repo.delete!(custom_record)
  end

  defp format_record(record, keys) do
    # Essentially this is just reordering.
    Enum.map(record, fn entry ->
      # For each entry, use the order specified by keys
      keys
      |> Enum.map(fn k -> entry[k] end)
      |> Enum.map(fn v -> format_value(v) end)
    end)
  end

  def write_record(file, record) do
    # First the headers for the csv file will be generated
    [entry | _] = record
    keys = Map.keys(entry)
    # The first element in the `outputs` list of lists will be the keys, i.e. headers
    outputs = [keys]

    # For each entry, concatenate it to the `outputs` list.
    outputs = outputs ++ format_record(record, keys)
    outputs |> CSV.encode() |> Enum.each(&IO.write(file, &1))
  end

  defp convert_uploaded_data(upload) do
    case upload.content_type do
      "application/json" ->
        data =
          upload.path
          |> File.read!()
          |> Jason.decode!()

        {:ok, data}

      "text/csv" ->
        data =
          upload.path
          |> File.stream!()
          # TODO: Should probably use the gentler `decode` version and manually pass down the errors. Or maybe one should simply separate the conversion for JSON and CSV into two separate functions.
          |> CSV.decode!(headers: true)
          # Because it returns a stream, we just simply make the results concrete here.
          |> Enum.take_every(1)

        {:ok, data}

      _ ->
        :error
    end
  end

  def retrieve_custom_record_as_csv(%CustomRecord{} = custom_record) do
    {:ok, file_path} = Briefly.create()
    file = File.open!(file_path, [:write, :utf8])
    write_record(file, custom_record.record)
    File.close(file)

    {:ok, file_path}
  end
end
