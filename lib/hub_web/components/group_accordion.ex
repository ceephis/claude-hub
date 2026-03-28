defmodule HubWeb.GroupAccordion do
  use Phoenix.Component
  import HubWeb.ProjectCard, only: [project_card: 1, mini_project_card: 1]

  # ---------------------------------------------------------------------------
  # Top-level entry point
  # ---------------------------------------------------------------------------

  attr :groups,        :list,    required: true
  attr :uncategorized, :list,    required: true
  attr :expanded,      :any,     required: true
  attr :filters,       :list,    required: true
  attr :search,        :string,  default: ""
  attr :editing_group, :string,  default: nil
  attr :adding_to,     :string,  default: nil
  attr :group_options, :list,    default: []
  attr :committing,    :string,  default: nil

  def group_list(assigns) do
    ~H"""
    <div class="space-y-1">
      <%= for group <- @groups do %>
        <.group_node
          group={group}
          expanded={@expanded}
          filters={@filters}
          search={@search}
          editing_group={@editing_group}
          adding_to={@adding_to}
          group_options={@group_options}
          committing={@committing}
          depth={0}
        />
      <% end %>

      <%!-- Inline form for new top-level group --%>
      <%= if @adding_to == "root" do %>
        <.new_group_form parent_id="root" />
      <% end %>

      <%= if length(@uncategorized) > 0 do %>
        <.uncategorized_section cards={@uncategorized} filters={@filters} search={@search} group_options={@group_options} committing={@committing} />
      <% end %>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Single group node
  # ---------------------------------------------------------------------------

  attr :group,         :map,     required: true
  attr :expanded,      :any,     required: true
  attr :filters,       :list,    required: true
  attr :search,        :string,  default: ""
  attr :editing_group, :string,  default: nil
  attr :adding_to,     :string,  default: nil
  attr :group_options, :list,    default: []
  attr :committing,    :string,  default: nil
  attr :depth,         :integer, default: 0

  def group_node(assigns) do
    assigns =
      assigns
      |> assign(:is_open,       MapSet.member?(assigns.expanded, assigns.group.id) or assigns.search != "")
      |> assign(:visible_cards, visible_cards(assigns.group.cards, assigns.filters, assigns.search))
      |> assign(:total_count,   deep_count(assigns.group, assigns.filters, assigns.search))
      |> assign(:is_editing,    assigns.editing_group == assigns.group.id)
      |> assign(:is_adding,     assigns.adding_to == assigns.group.id)
      |> assign(:deep_cards,    collect_deep_cards(assigns.group, assigns.filters, assigns.search))

    ~H"""
    <div class={depth_class(@depth)}>
      <%!-- Group header --%>
      <div class="flex items-center gap-1 px-2 py-1.5 rounded-lg hover:bg-gray-800 transition-colors">

        <%!-- Expand toggle --%>
        <button
          phx-click="toggle_group"
          phx-value-id={@group.id}
          class="text-gray-500 text-xs w-4 shrink-0 transition-transform"
        >
          <%= if @is_open, do: "▼", else: "▶" %>
        </button>

        <%!-- Name or inline rename input --%>
        <%= if @is_editing do %>
          <form phx-submit="rename_group" class="flex items-center gap-1 flex-1">
            <input type="hidden" name="group_id" value={@group.id} />
            <input
              type="text"
              name="name"
              value={@group.name}
              autofocus
              class="bg-gray-700 text-white text-sm rounded px-2 py-0.5 flex-1 outline-none border border-indigo-500"
              phx-keydown="cancel_edit"
              phx-key="Escape"
            />
            <button type="submit" class="text-green-400 text-xs hover:text-green-300 px-1">✓</button>
            <button type="button" phx-click="cancel_edit" class="text-gray-500 text-xs hover:text-gray-300 px-1">✕</button>
          </form>
        <% else %>
          <button
            phx-click="toggle_group"
            phx-value-id={@group.id}
            class="flex-1 flex items-center gap-2 text-left"
          >
            <span class={depth_text_class(@depth)}>{@group.name}</span>
            <span class="text-xs text-gray-600 font-mono">({@total_count})</span>
            <div class="flex gap-0.5">
              <%= for {key, count} <- status_summary(@group, @filters), count > 0 do %>
                <span class="text-xs leading-none">{status_dot(key)}</span>
              <% end %>
            </div>
          </button>

          <%!-- Action buttons --%>
          <div class="flex items-center gap-0.5 shrink-0">
            <button
              phx-click="start_add_group"
              phx-value-parent_id={@group.id}
              title="Add subgroup"
              class="text-gray-500 hover:text-green-400 text-sm px-1 py-0.5 rounded hover:bg-gray-700"
            >+</button>
            <button
              phx-click="start_edit_group"
              phx-value-id={@group.id}
              title="Rename"
              class="text-gray-500 hover:text-blue-400 text-xs px-1 py-0.5 rounded hover:bg-gray-700"
            >✏</button>
            <%= if @total_count == 0 do %>
              <button
                phx-click="delete_group"
                phx-value-id={@group.id}
                title="Delete empty group"
                class="text-gray-500 hover:text-red-400 text-xs px-1 py-0.5 rounded hover:bg-gray-700"
                data-confirm="Delete group {@group.name}?"
              >✕</button>
            <% end %>
          </div>
        <% end %>
      </div>

      <%!-- Expanded content --%>
      <%= if @is_open do %>
        <div class="ml-5 border-l border-gray-800 pl-2 mt-0.5">

          <%= if length(@group.groups) > 0 do %>
            <%!-- Intermediate level: mini overview cards for all deep projects --%>
            <%= if length(@deep_cards) > 0 do %>
              <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 gap-2 py-2">
                <%= for project <- @deep_cards do %>
                  <.mini_project_card project={project} />
                <% end %>
              </div>
              <div class="border-t border-gray-800 my-2"></div>
            <% end %>

            <%!-- Child group rows --%>
            <%= for child <- @group.groups do %>
              <.group_node
                group={child}
                expanded={@expanded}
                filters={@filters}
                search={@search}
                editing_group={@editing_group}
                adding_to={@adding_to}
                group_options={@group_options}
                committing={@committing}
                depth={@depth + 1}
              />
            <% end %>

            <%!-- Inline new subgroup form --%>
            <%= if @is_adding do %>
              <.new_group_form parent_id={@group.id} />
            <% end %>

          <% else %>
            <%!-- Leaf level: full cards --%>
            <%= if length(@visible_cards) > 0 do %>
              <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4 py-3">
                <%= for project <- @visible_cards do %>
                  <.project_card project={project} group_options={@group_options} committing={@committing} />
                <% end %>
              </div>
            <% end %>

            <%!-- Inline new subgroup form --%>
            <%= if @is_adding do %>
              <.new_group_form parent_id={@group.id} />
            <% end %>

            <%= if length(@visible_cards) == 0 and not @is_adding do %>
              <p class="text-xs text-gray-600 px-2 py-2 italic">
                <%= if @filters != [], do: "No projects match the current filter.", else: "Empty group." %>
              </p>
            <% end %>
          <% end %>

        </div>
      <% end %>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Inline new group form
  # ---------------------------------------------------------------------------

  attr :parent_id, :string, required: true

  def new_group_form(assigns) do
    ~H"""
    <form phx-submit="create_group" class="flex items-center gap-1 px-2 py-1">
      <input type="hidden" name="parent_id" value={@parent_id} />
      <span class="text-gray-500 text-xs">▶</span>
      <input
        type="text"
        name="name"
        placeholder="Group name..."
        autofocus
        class="bg-gray-700 text-white text-sm rounded px-2 py-0.5 flex-1 outline-none border border-indigo-500"
        phx-keydown="cancel_edit"
        phx-key="Escape"
      />
      <button type="submit" class="text-green-400 text-xs hover:text-green-300 px-1">✓</button>
      <button type="button" phx-click="cancel_edit" class="text-gray-500 text-xs hover:text-gray-300 px-1">✕</button>
    </form>
    """
  end

  # ---------------------------------------------------------------------------
  # Uncategorized
  # ---------------------------------------------------------------------------

  attr :cards,         :list,   required: true
  attr :filters,       :list,   required: true
  attr :search,        :string, default: ""
  attr :group_options, :list,   default: []
  attr :committing,    :string, default: nil

  def uncategorized_section(assigns) do
    assigns = assign(assigns, :visible, visible_cards(assigns.cards, assigns.filters, assigns.search))

    ~H"""
    <%= if length(@visible) > 0 do %>
      <div>
        <div class="flex items-center gap-2 px-3 py-2">
          <span class="font-semibold tracking-wide text-xs text-gray-500 uppercase">Uncategorized</span>
          <span class="text-xs text-gray-600 font-mono">({length(@visible)})</span>
        </div>
        <div class="ml-5 grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4 py-3">
          <%= for project <- @visible do %>
            <.project_card project={project} group_options={@group_options} committing={@committing} />
          <% end %>
        </div>
      </div>
    <% end %>
    """
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp visible_cards(cards, filters, search) do
    cards
    |> then(fn c -> if filters == [], do: c, else: Enum.filter(c, &(&1.status_key in filters)) end)
    |> then(fn c -> if search == "", do: c, else: Enum.filter(c, &matches_search?(&1, search)) end)
  end

  defp matches_search?(project, search) do
    String.contains?(String.downcase(project.name), String.downcase(search))
  end

  defp deep_count(group, filters, search) do
    direct = length(visible_cards(group.cards, filters, search))
    nested = Enum.sum(Enum.map(group.groups, &deep_count(&1, filters, search)))
    direct + nested
  end

  defp status_summary(group, filters) do
    all_cards = collect_all_cards(group)
    visible   = visible_cards(all_cards, filters, "")
    [:active, :planning, :paused, :live]
    |> Enum.map(fn key -> {key, Enum.count(visible, &(&1.status_key == key))} end)
  end

  defp collect_all_cards(group) do
    group.cards ++ Enum.flat_map(group.groups, &collect_all_cards/1)
  end

  # Cards from child groups only (not direct cards of this group)
  defp collect_deep_cards(group, filters, search) do
    group.groups
    |> Enum.flat_map(&collect_all_cards/1)
    |> then(&visible_cards(&1, filters, search))
    |> Enum.sort_by(& &1.name)
  end

  defp depth_class(0), do: "mb-1"
  defp depth_class(_), do: "mb-0.5"

  defp depth_text_class(0), do: "text-gray-200 uppercase tracking-widest text-xs font-bold"
  defp depth_text_class(1), do: "text-gray-300 uppercase tracking-wider text-xs font-semibold"
  defp depth_text_class(_), do: "text-gray-400 text-xs"

  defp status_dot(:active),   do: "🟢"
  defp status_dot(:planning), do: "🟡"
  defp status_dot(:paused),   do: "🔴"
  defp status_dot(:live),     do: "✅"
  defp status_dot(_),         do: "⚪"
end
