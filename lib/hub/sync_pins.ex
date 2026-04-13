defmodule Hub.SyncPins do
  @path       Path.expand("~/Desktop/Claude/.sync_pins.json")
  @report_path Path.expand("~/Desktop/Claude/.sync_report.json")

  def load do
    case File.read(@path) do
      {:ok, json} ->
        case Jason.decode(json) do
          {:ok, list} when is_list(list) -> MapSet.new(list)
          _ -> MapSet.new()
        end
      _ -> MapSet.new()
    end
  end

  def save(pinned) do
    json = pinned |> MapSet.to_list() |> Jason.encode!()
    File.write!(@path, json)
  end

  def toggle(pinned, folder) do
    updated = if MapSet.member?(pinned, folder), do: MapSet.delete(pinned, folder), else: MapSet.put(pinned, folder)
    save(updated)
    updated
  end

  def save_report(results) do
    data = Enum.map(results, fn r ->
      pushed = case r.pushed do
        :ok        -> "ok"
        :no_remote -> "no_remote"
        nil        -> nil
        {:error, msg} -> %{"error" => msg}
        other      -> to_string(other)
      end
      %{"name" => r.name, "status" => to_string(r.status), "pushed" => pushed}
    end)
    File.write!(@report_path, Jason.encode!(data))
  end

  def load_report do
    case File.read(@report_path) do
      {:ok, json} ->
        case Jason.decode(json) do
          {:ok, list} when is_list(list) ->
            Enum.map(list, fn r ->
              pushed = case r["pushed"] do
                "ok"        -> :ok
                "no_remote" -> :no_remote
                nil         -> nil
                %{"error" => msg} -> {:error, msg}
                other       -> String.to_atom(other)
              end
              %{name: r["name"], status: String.to_atom(r["status"]), pushed: pushed}
            end)
          _ -> nil
        end
      _ -> nil
    end
  end

  def clear_report, do: File.rm(@report_path)
end
