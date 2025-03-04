local notify = require "nvim-tree.notify"

local Api = {
  tree = {},
  node = { navigate = { sibling = {}, git = {}, diagnostics = {}, opened = {} }, run = {}, open = {} },
  events = {},
  marks = { bulk = {}, navigate = {} },
  fs = { copy = {} },
  git = {},
  live_filter = {},
  config = { mappings = {} },
  commands = {},
}

--- Do nothing when setup not called.
--- f function to invoke
local function wrap(f)
  return function()
    if vim.g.NvimTreeSetup == 1 then
      return f()
    else
      notify.error "nvim-tree setup not called"
    end
  end
end

--- Inject the node as the first argument if absent.
--- f function to invoke
local function wrap_node(f)
  return function(node, ...)
    node = node or require("nvim-tree.lib").get_node_at_cursor()
    f(node, ...)
  end
end

---@class ApiTreeOpenOpts
---@field path string|nil path
---@field current_window boolean|nil default false
---@field find_file boolean|nil default false
---@field update_root boolean|nil default false

Api.tree.open = wrap(require("nvim-tree.actions.tree.open").fn)

---@class ApiTreeToggleOpts
---@field path string|nil
---@field current_window boolean|nil default false
---@field find_file boolean|nil default false
---@field update_root boolean|nil default false
---@field focus boolean|nil default true

Api.tree.toggle = wrap(require("nvim-tree.actions.tree.toggle").fn)

Api.tree.close = wrap(require("nvim-tree.view").close)

Api.tree.close_in_this_tab = wrap(require("nvim-tree.view").close_this_tab_only)

Api.tree.close_in_all_tabs = wrap(require("nvim-tree.view").close_all_tabs)

Api.tree.focus = wrap(function()
  require("nvim-tree").focus()
end)

Api.tree.reload = wrap(require("nvim-tree.actions.reloaders.reloaders").reload_explorer)

Api.tree.change_root = wrap(function(...)
  require("nvim-tree").change_dir(...)
end)

Api.tree.change_root_to_node = wrap_node(function(node)
  if node.name == ".." then
    require("nvim-tree.actions.root.change-dir").fn ".."
  elseif node.nodes ~= nil then
    require("nvim-tree.actions.root.change-dir").fn(require("nvim-tree.lib").get_last_group_node(node).absolute_path)
  end
end)

Api.tree.change_root_to_parent = wrap_node(require("nvim-tree.actions.root.dir-up").fn)

Api.tree.get_node_under_cursor = wrap(require("nvim-tree.lib").get_node_at_cursor)

Api.tree.get_nodes = wrap(require("nvim-tree.lib").get_nodes)

---@class ApiTreeFindFileOpts
---@field buf string|number|nil
---@field open boolean|nil default false
---@field current_window boolean|nil default false
---@field update_root boolean|nil default false
---@field focus boolean|nil default false

Api.tree.find_file = wrap(require("nvim-tree.actions.tree.find-file").fn)

Api.tree.search_node = wrap(require("nvim-tree.actions.finders.search-node").fn)

Api.tree.collapse_all = wrap(require("nvim-tree.actions.tree-modifiers.collapse-all").fn)

Api.tree.expand_all = wrap_node(require("nvim-tree.actions.tree-modifiers.expand-all").fn)

Api.tree.toggle_gitignore_filter = wrap(require("nvim-tree.actions.tree-modifiers.toggles").git_ignored)

Api.tree.toggle_git_clean_filter = wrap(require("nvim-tree.actions.tree-modifiers.toggles").git_clean)

Api.tree.toggle_no_buffer_filter = wrap(require("nvim-tree.actions.tree-modifiers.toggles").no_buffer)

Api.tree.toggle_custom_filter = wrap(require("nvim-tree.actions.tree-modifiers.toggles").custom)

Api.tree.toggle_hidden_filter = wrap(require("nvim-tree.actions.tree-modifiers.toggles").dotfiles)

Api.tree.toggle_help = wrap(require("nvim-tree.help").toggle)

Api.fs.create = wrap_node(require("nvim-tree.actions.fs.create-file").fn)
Api.fs.remove = wrap_node(require("nvim-tree.actions.fs.remove-file").fn)
Api.fs.trash = wrap_node(require("nvim-tree.actions.fs.trash").fn)
Api.fs.rename_node = wrap_node(require("nvim-tree.actions.fs.rename-file").fn ":t")
Api.fs.rename = wrap_node(require("nvim-tree.actions.fs.rename-file").fn ":t")
Api.fs.rename_sub = wrap_node(require("nvim-tree.actions.fs.rename-file").fn ":p:h")
Api.fs.rename_basename = wrap_node(require("nvim-tree.actions.fs.rename-file").fn ":t:r")
Api.fs.cut = wrap_node(require("nvim-tree.actions.fs.copy-paste").cut)
Api.fs.paste = wrap_node(require("nvim-tree.actions.fs.copy-paste").paste)
Api.fs.clear_clipboard = wrap(require("nvim-tree.actions.fs.copy-paste").clear_clipboard)
Api.fs.print_clipboard = wrap(require("nvim-tree.actions.fs.copy-paste").print_clipboard)
Api.fs.copy.node = wrap_node(require("nvim-tree.actions.fs.copy-paste").copy)
Api.fs.copy.absolute_path = wrap_node(require("nvim-tree.actions.fs.copy-paste").copy_absolute_path)
Api.fs.copy.filename = wrap_node(require("nvim-tree.actions.fs.copy-paste").copy_filename)
Api.fs.copy.relative_path = wrap_node(require("nvim-tree.actions.fs.copy-paste").copy_path)

local function edit(mode, node)
  local path = node.absolute_path
  if node.link_to and not node.nodes then
    path = node.link_to
  end
  require("nvim-tree.actions.node.open-file").fn(mode, path)
end

local function open_or_expand_or_dir_up(mode)
  return function(node)
    if node.name == ".." then
      require("nvim-tree.actions.root.change-dir").fn ".."
    elseif node.nodes then
      require("nvim-tree.lib").expand_or_collapse(node)
    else
      edit(mode, node)
    end
  end
end

local function open_preview(node)
  if node.name == ".." then
    require("nvim-tree.actions.root.change-dir").fn ".."
  elseif node.nodes then
    require("nvim-tree.lib").expand_or_collapse(node)
  else
    edit("preview", node)
  end
end

Api.node.open.edit = wrap_node(open_or_expand_or_dir_up "edit")
Api.node.open.replace_tree_buffer = wrap_node(open_or_expand_or_dir_up "edit_in_place")
Api.node.open.no_window_picker = wrap_node(open_or_expand_or_dir_up "edit_no_picker")
Api.node.open.vertical = wrap_node(open_or_expand_or_dir_up "vsplit")
Api.node.open.horizontal = wrap_node(open_or_expand_or_dir_up "split")
Api.node.open.tab = wrap_node(open_or_expand_or_dir_up "tabnew")
Api.node.open.preview = wrap_node(open_preview)

Api.node.show_info_popup = wrap_node(require("nvim-tree.actions.node.file-popup").toggle_file_info)
Api.node.run.cmd = wrap_node(require("nvim-tree.actions.node.run-command").run_file_command)
Api.node.run.system = wrap_node(require("nvim-tree.actions.node.system-open").fn)
Api.node.navigate.sibling.next = wrap_node(require("nvim-tree.actions.moves.sibling").fn "next")
Api.node.navigate.sibling.prev = wrap_node(require("nvim-tree.actions.moves.sibling").fn "prev")
Api.node.navigate.sibling.first = wrap_node(require("nvim-tree.actions.moves.sibling").fn "first")
Api.node.navigate.sibling.last = wrap_node(require("nvim-tree.actions.moves.sibling").fn "last")
Api.node.navigate.parent = wrap_node(require("nvim-tree.actions.moves.parent").fn(false))
Api.node.navigate.parent_close = wrap_node(require("nvim-tree.actions.moves.parent").fn(true))
Api.node.navigate.git.next = wrap_node(require("nvim-tree.actions.moves.item").fn("next", "git"))
Api.node.navigate.git.prev = wrap_node(require("nvim-tree.actions.moves.item").fn("prev", "git"))
Api.node.navigate.diagnostics.next = wrap_node(require("nvim-tree.actions.moves.item").fn("next", "diag"))
Api.node.navigate.diagnostics.prev = wrap_node(require("nvim-tree.actions.moves.item").fn("prev", "diag"))
Api.node.navigate.opened.next = wrap_node(require("nvim-tree.actions.moves.item").fn("next", "opened"))
Api.node.navigate.opened.prev = wrap_node(require("nvim-tree.actions.moves.item").fn("prev", "opened"))

Api.git.reload = wrap(require("nvim-tree.actions.reloaders.reloaders").reload_git)

Api.events.subscribe = require("nvim-tree.events").subscribe
Api.events.Event = require("nvim-tree.events").Event

Api.live_filter.start = wrap(require("nvim-tree.live-filter").start_filtering)
Api.live_filter.clear = wrap(require("nvim-tree.live-filter").clear_filter)

Api.marks.get = wrap_node(require("nvim-tree.marks").get_mark)
Api.marks.list = wrap(require("nvim-tree.marks").get_marks)
Api.marks.toggle = wrap_node(require("nvim-tree.marks").toggle_mark)
Api.marks.clear = wrap(require("nvim-tree.marks").clear_marks)
Api.marks.bulk.move = wrap(require("nvim-tree.marks.bulk-move").bulk_move)
Api.marks.navigate.next = wrap(require("nvim-tree.marks.navigation").next)
Api.marks.navigate.prev = wrap(require("nvim-tree.marks.navigation").prev)
Api.marks.navigate.select = wrap(require("nvim-tree.marks.navigation").select)

Api.config.mappings.default_on_attach = require("nvim-tree.keymap").default_on_attach

Api.config.mappings.active = wrap(function()
  notify.warn "api.config.mappings.active is deprecated in favor of config.mappings.get_keymap"
  return require("nvim-tree.keymap-legacy").active_mappings_clone()
end)

Api.config.mappings.default = function()
  notify.warn "api.config.mappings.default is deprecated in favor of config.mappings.get_keymap_default"
  return require("nvim-tree.keymap-legacy").default_mappings_clone()
end

Api.config.mappings.get_keymap = wrap(function()
  return require("nvim-tree.keymap").get_keymap()
end)

Api.config.mappings.get_keymap_default = wrap(function()
  return require("nvim-tree.keymap").get_keymap_default()
end)

Api.commands.get = wrap(function()
  return require("nvim-tree.commands").get()
end)

return Api
