defmodule Hub.Groups do
  @groups_path Path.expand("~/Desktop/Claude/hub/groups.json")

  # ---------------------------------------------------------------------------
  # Load / Save
  # ---------------------------------------------------------------------------

  def load do
    case File.read(@groups_path) do
      {:ok, json} ->
        json |> Jason.decode!() |> Map.get("groups", []) |> Enum.map(&decode_group(&1, ""))
      {:error, _} ->
        default_groups()
    end
  end

  def save(groups) do
    data = %{"groups" => Enum.map(groups, &encode_group/1)}
    File.write!(@groups_path, Jason.encode!(data, pretty: true))
  end

  # ---------------------------------------------------------------------------
  # Assign projects into the recursive group tree
  # ---------------------------------------------------------------------------

  def assign_projects(groups, projects) do
    project_index = Map.new(projects, &{&1.folder, &1})
    assigned      = all_assigned_folders(groups)
    enriched      = Enum.map(groups, &attach_cards(&1, project_index))
    unassigned    = Enum.reject(projects, &MapSet.member?(assigned, &1.folder))
    {enriched, unassigned}
  end

  def all_assigned_folders(groups) do
    Enum.reduce(groups, MapSet.new(), fn g, acc ->
      acc
      |> MapSet.union(MapSet.new(g.projects))
      |> MapSet.union(all_assigned_folders(g.groups))
    end)
  end

  # ---------------------------------------------------------------------------
  # CRUD operations (operate on the raw group tree, before assign_projects)
  # ---------------------------------------------------------------------------

  def create_group(groups, "root", name) do
    groups ++ [new_group(name, "")]
  end

  def create_group(groups, parent_id, name) do
    map_group(groups, parent_id, fn g ->
      child = new_group(name, g.id)
      %{g | groups: g.groups ++ [child]}
    end)
  end

  def rename_group(groups, id, new_name) do
    map_group(groups, id, fn g -> %{g | name: new_name} end)
  end

  def delete_group(groups, id) do
    groups
    |> Enum.reject(&(&1.id == id))
    |> Enum.map(fn g -> %{g | groups: delete_group(g.groups, id)} end)
  end

  def move_group(groups, id, direction) do
    groups
    |> move_in_list(id, direction)
    |> Enum.map(fn g -> %{g | groups: move_group(g.groups, id, direction)} end)
  end

  defp move_in_list(list, id, direction) do
    case Enum.find_index(list, &(&1.id == id)) do
      nil -> list
      idx ->
        swap = if direction == :up, do: idx - 1, else: idx + 1
        if swap < 0 or swap >= length(list) do
          list
        else
          list
          |> List.replace_at(idx, Enum.at(list, swap))
          |> List.replace_at(swap, Enum.at(list, idx))
        end
    end
  end

  def move_project(groups, folder, to_id) do
    groups
    |> remove_project_everywhere(folder)
    |> add_project_to(folder, to_id)
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp attach_cards(group, index) do
    cards    = group.projects |> Enum.map(&Map.get(index, &1)) |> Enum.reject(&is_nil/1)
    children = Enum.map(group.groups, &attach_cards(&1, index))
    group |> Map.put(:cards, cards) |> Map.put(:groups, children)
  end

  defp map_group(groups, target_id, fun) do
    Enum.map(groups, fn g ->
      if g.id == target_id do
        fun.(g)
      else
        %{g | groups: map_group(g.groups, target_id, fun)}
      end
    end)
  end

  defp remove_project_everywhere(groups, folder) do
    Enum.map(groups, fn g ->
      %{g |
        projects: Enum.reject(g.projects, &(&1 == folder)),
        groups:   remove_project_everywhere(g.groups, folder)
      }
    end)
  end

  defp add_project_to(groups, _folder, "uncategorized"), do: groups

  defp add_project_to(groups, folder, to_id) do
    map_group(groups, to_id, fn g ->
      %{g | projects: g.projects ++ [folder]}
    end)
  end

  defp new_group(name, parent_id) do
    slug = slugify(name)
    id   = if parent_id == "", do: slug, else: "#{parent_id}/#{slug}"
    %{id: id, name: name, projects: [], groups: []}
  end

  defp decode_group(g, parent_id) do
    slug = slugify(g["name"] || "group")
    id   = if parent_id == "", do: slug, else: "#{parent_id}/#{slug}"
    %{
      id:       id,
      name:     g["name"] || "Group",
      projects: g["projects"] || [],
      groups:   Enum.map(g["groups"] || [], &decode_group(&1, id))
    }
  end

  defp encode_group(g) do
    %{
      "name"     => g.name,
      "projects" => g.projects,
      "groups"   => Enum.map(g.groups, &encode_group/1)
    }
  end

  def slugify(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.trim("-")
  end

  # ---------------------------------------------------------------------------
  # Find the path of group IDs from root to the group containing a folder
  # Returns list of group IDs e.g. ["my-projects", "my-projects/active"]
  # ---------------------------------------------------------------------------

  def path_to_project(groups, folder) do
    find_path(groups, folder, [])
  end

  defp find_path([], _folder, _acc), do: nil

  defp find_path([group | rest], folder, acc) do
    cond do
      folder in group.projects ->
        Enum.reverse([group.id | acc])

      result = find_path(group.groups, folder, [group.id | acc]) ->
        result

      true ->
        find_path(rest, folder, acc)
    end
  end

  # ---------------------------------------------------------------------------
  # Flat list of all groups for dropdowns (id, name, depth)
  # ---------------------------------------------------------------------------

  def flat_list(groups, depth \\ 0) do
    Enum.flat_map(groups, fn g ->
      [{g.id, g.name, depth}] ++ flat_list(g.groups, depth + 1)
    end)
  end

  # ---------------------------------------------------------------------------
  # Defaults
  # ---------------------------------------------------------------------------

  defp default_groups do
    [
      %{id: "my-projects", name: "MY PROJECTS", projects: [],
        groups: [
          %{id: "my-projects/active",   name: "ACTIVE",   projects: ["EMDR", "social", "test1"], groups: []},
          %{id: "my-projects/planning", name: "PLANNING", projects: ["ifs", "pill", "silence", "Transcendent"], groups: []}
        ]},
      %{id: "client-work", name: "CLIENT WORK", projects: ["lemonade", "palani"], groups: []},
      %{id: "torey",       name: "TOREY",        projects: ["security", "spotlight", "teagles"], groups: []},
      %{id: "ideas",       name: "IDEAS",         projects: [], groups: []}
    ]
  end
end
