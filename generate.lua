local colorscheme_path = vim.uv.cwd() .. '/Eva-Theme.nvim/lua/?.lua'
package.path = package.path .. ';' .. colorscheme_path
local function variant_name(variant)
  local function capitalize_first_letter(word)
    return word:sub(1, 1):upper() .. word:sub(2):lower()
  end
  local result = variant:gsub('(%a+)', capitalize_first_letter)
  return 'Eva-' .. result:gsub('_', '-')
end
local function helix(h)
  h:map_token(
    'operator',
    'ui.cursorrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr'
  )
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
  return is_primitive_list(t) and ('[%s]'):format(ret) or ('{ %s }'):format(ret)
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
