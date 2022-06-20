local util = require("trouble.util")

local M = {}

local function is_ready(feature)
  feature = string.sub(feature, 0, -2)
  if vim.g.coc_service_initialized ~= 1 then
    util.error("Coc is not ready yet!")
    return false
  end

  if feature and not vim.fn.CocHasProvider(feature) then
    util.error("Coc: language server does not support " .. feature .. " provider")
    return false
  end

  return true
end

function M.diagnostics(_, bufnr, cb, options)
  local items = {}

  local raw = vim.fn["coc#rpc#request"]("diagnosticList", {})
  local current_file = vim.api.nvim_buf_get_name(bufnr)

  -- type reference: https://github.com/neoclide/coc.nvim/blob/87239c26f7c2f75266bf04ce2c9a314063e4d935/typings/index.d.ts#L7822
  -- @table item
  -- @field severity "Error" | "Warning" | "Info" | "Hint"
  -- @field level 1 | 2 | 3 | 4
  for _, item in pairs(raw) do
    local range = item.location.range
      or {
        ["start"] = {
          character = item.col,
          line = item.lnum,
        },
        ["end"] = {
          character = item.end_col,
          line = item.end_lnum,
        },
      }
    local start = range["start"]
    local finish = range["end"]

    if start.character == nil or start.line == nil then
      M.error("Found an item for Trouble without start range " .. vim.inspect(start))
    end
    if finish.character == nil or finish.line == nil then
      M.error("Found an item for Trouble without finish range " .. vim.inspect(finish))
    end
    local row = start.line
    local col = start.character

    if not item.message then
      vim.fn.bufload(bufnr)
      local line = (vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false) or { "" })[1]
      item.message = item.message or line or ""
    end

    if options.mode == "coc_document_diagnostics" and current_file ~= item.file then
      goto continue
    end

    table.insert(items, {
      bufnr = bufnr,
      filename = item.file,
      lnum = row + 1,
      col = col + 1,
      start = start,
      finish = finish,
      sign = vim.fn.sign_getdefined("Coc" .. item.severity)[1]["text"],
      sign_hl = ("Coc%sSign"):format(item.severity),
      text = vim.trim(item.message:gsub("[\n]", "")):sub(0, vim.o.columns),
      full_text = vim.trim(item.message),
      type = util.severity[item.level] or util.severity[0],
      code = item.code or "",
      source = item.source,
      severity = item.level or 0,
    })

    ::continue::
  end

  cb(items)
end

local function to_items(win, method, opts)
  vim.fn.win_gotoid(win)

  if not is_ready(method) then
    return {}
  end

  local items = {}

  vim.fn.CocAction("ensureDocument")

  local raw = vim.fn["coc#rpc#request"](method, opts.args or {})

  if not type(raw) == "table" then
    return {}
  end

  for _, item in pairs(raw or {}) do
    local start = item.range["start"]
    local finish = item.range["end"]
    local row = start.line
    local col = start.character

    local item_bufnr = vim.uri_to_bufnr(item.uri)
    local item_fname = vim.uri_to_fname(item.uri)
    vim.fn.bufload(item_bufnr)
    local line = vim.api.nvim_buf_get_lines(item_bufnr, row, row + 1, false)[1] or "Text not available!"

    table.insert(items, {
      bufnr = item_bufnr,
      filename = item_fname,
      uri = item.uri,
      lnum = row + 1,
      col = col + 1,
      start = start,
      finish = finish,
      sign = "⏺",
      sign_hl = "LineNr",
      text = vim.trim(line),
      full_text = line,
      type = "Other",
      code = nil,
      source = nil,
      severity = 0,
    })
  end

  return items
end

function M.references(win, _, cb, _)
  cb(to_items(win, "references", { args = { false } }))
end

function M.references_used(win, _, cb, _)
  cb(to_items(win, "references", { args = { true } }))
end

function M.definitions(win, _, cb, _)
  cb(to_items(win, "definitions", {}))
end

function M.type_definitions(win, _, cb, _)
  cb(to_items(win, "typeDefinitions", {}))
end

function M.implementations(win, _, cb, _)
  cb(to_items(win, "implementations", {}))
end

function M.declarations(win, _, cb, _)
  cb(to_items(win, "declarations", {}))
end

return M
