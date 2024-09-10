local colorscheme_path = vim.uv.cwd() .. '/Eva-Theme.nvim/lua/?.lua'
package.path = package.path .. ';' .. colorscheme_path
local utils = require('Eva-Theme.utils')
local function variant_name(variant)
  local function capitalize_first_letter(word)
    return word:sub(1, 1):upper() .. word:sub(2):lower()
  end
  local result = variant:gsub('(%a+)', capitalize_first_letter)
  return 'Eva-' .. result:gsub('_', '-')
end
local function helix(h)
  h:map_ui('background', 'ui.background')
    :map_ui('NONE', 'ui.menu.selected', function(palette, _)
      return {
        bg = utils.is_dark(palette) and '#2F3F5C' or '#CAD7ED',
        fg = utils.is_dark(palette) and '#D7DAE0' or '#5D5D5F',
      }
    end)
    :map_ui('NONE', { 'ui.cursorline.primary', 'ui.statusline' }, function(p, _)
      return { bg = utils.is_dark(p) and '#2F323C' or '#E3E6ED' }
    end)
    :map_ui('NONE', 'diagnostic.hint', function(p, _)
      return { bg = p.inlay_hint.bg, fg = utils.is_dark(p) and '#50567C' or '#C8CACE' }
    end)
    :map_ui('NONE', 'diagnostic.info', function(p, _)
      return { fg = utils.is_dark(p) and '#00b7cb' or '#00c1ea', bg = utils.is_dark(p) and '#233e4b' or '#cde7f3' }
    end)
    :map_ui('NONE', 'diagnostic.warning', function(p, _)
      return { fg = utils.is_dark(p) and '#EF973A' or '#FB942F', bg = utils.is_dark(p) and '#463D3A' or '#E7DBD4' }
    end)
    :map_ui('NONE', 'diagnostic.error', function(p, _)
      return { fg = utils.is_dark(p) and '#F36464' or '#E45454', bg = utils.is_dark(p) and '#3D3037' or '#EBDAE0' }
    end)
    :map_ui('NONE', 'diagnostic.unnecessary', function(palette, _)
      return { fg = utils.is_dark(palette) and '#50567C' or '#C8CACE' }
    end)
    :map_ui('NONE', 'ui.selection', function(p, _)
      return { bg = utils.is_dark(p) and '#394E75' or '#B0CBF7' }
    end)
    :map_ui('NONE', 'ui.virtual.inlay-hint', function(palette, _)
      return {
        fg = palette.inlay_hint.fg,
        bg = palette.inlay_hint.bg,
      }
    end)
    :map_ui('NONE', 'ui.linenr', function(palette, _)
      return { fg = utils.is_dark(palette) and '#50567C' or '#C8CACE' }
    end)
    :map_ui('variable', { 'ui.linenr.selected', 'ui.text' })
end

local Palette = require('Eva-Theme.palette')
local registration = require('Eva-Theme.highlight_registration'):with(helix)
local themes = {
  'light',
  'light_bold',
  'light_italic',
  'light_italic_bold',
  'dark',
  'dark_bold',
  'dark_italic',
  'dark_italic_bold',
}

local function transform_style(t)
  local modifiers = { 'bold', 'italic', 'underlined' }
  local none = { 'nocombine' }
  for _, value in pairs(none) do
    if vim.tbl_contains(vim.tbl_keys(t), value) then
      t[value] = nil
    end
  end
  for _, value in pairs(modifiers) do
    if vim.tbl_contains(vim.tbl_keys(t), value) then
      t.modifiers = t.modifiers or {}
      t.modifiers[#t.modifiers + 1] = value
      t[value] = nil
    end
  end
  return t
end

---convert lua table to toml string
---@param t table
---@return string
local function convert_toml_obj(t)
  local function is_primitive_list(l)
    return vim.islist(l)
      and vim.iter(l):all(function(x)
        return type(x) == 'number' or type(x) == 'string' or type(x) == 'boolean'
      end)
  end
  local ret = ''
  for key, value in pairs(t) do
    local c
    if type(value) == 'table' and not is_primitive_list(value) then
      c = key .. ' = ' .. convert_toml_obj(value)
    elseif is_primitive_list(value) then
      c = key .. ' = ' .. vim.inspect(value):gsub('{(.-)}', function(cap)
        return '[' .. cap .. ']'
      end)
    else
      c = type(key) == 'number' and vim.inspect(value) or key .. ' = ' .. vim.inspect(value)
    end
    ret = table.concat(ret == '' and { c } or { ret, c }, ', ')
  end
  return (is_primitive_list(t) and '[%s]' or '{ %s }'):format(ret)
end
for _, theme in pairs(themes) do
  local palette = Palette:from_variant(theme)
  local groups = registration:highlight_groups(palette)
  local helix_groups = {}
  vim
    .iter(vim.tbl_keys(groups))
    :filter(function(k) -- filter treesitter and helix scopes
      k = k --[[@as string]]
      return vim.iter({ '@', 'markup', 'ui', 'diagnostic', 'warning', 'error', 'info', 'hint' }):any(function(x)
        return k:sub(1, #x) == x
      end)
    end)
    :each(function(k) -- truncate leading `@` of treesitter scopes
      helix_groups[k:sub(1, 1) == '@' and k:sub(2) or k] = transform_style(groups[k])
    end)
  local f = io.open(variant_name(theme) .. '.toml', 'w')
  if f then
    for key, value in pairs(helix_groups) do
      f:write(('"%s" = %s\n'):format(key, convert_toml_obj(value)))
    end
    f:close()
  end
end
