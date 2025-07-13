---@class M
---@field paths string[]
---@field spec RootSpec

---@alias RootFn fun(buffer: number): (string|string[])
---@alias RootSpec string|string[]|RootFn

local M = {}

--- The default root spec.
---
---@type RootSpec[]
M.default_spec = { "lsp", { ".git", "lua" }, "cwd" }

--- The default root detectors.
---
--- Detectors:
--- - `cwd`: from the current working directory.
--- - `lsp`: using lsp
--- - `pattern`: using a specific pattern/filename/wildcard
---
---@type table
M.detectors = {
  --- Detect the root from the current working directory.
  ---
  --- ### Example:
  --- ```lua
  --- M.detectors.cwd() -- { "/Users/flashios09/.config/nvim/" }
  --- ```
  ---@param buffer? number|nil The `buffer`, e.g. `1`.
  ---@return table<string|nil> A table with the current working directory, `nil` otherwise.
  cwd = function(buffer)
    return { M.cwd(buffer) }
  end,

  --- Detect the root from lsp.
  ---
  --- ### Example:
  --- ```lua
  --- M.detectors.lsp(1) -- { "/Users/flashios09/.config/nvim/" }
  --- ```
  ---@param buffer number The buffer number, e.g. `1`
  ---@return table|table<string> A string table paths, empty table otherwise.
  lsp = function(buffer)
    local buffer_path = M.bufpath(buffer)

    if not buffer_path then
      return {}
    end

    local roots = {} ---@type string[]
    local clients = vim.lsp.get_clients({ bufnr = buffer })

    clients = vim.tbl_filter(function(client)
      return not vim.tbl_contains(vim.g.root_lsp_ignore or {}, client.name)
    end, clients)

    for _, client in pairs(clients) do
      local workspace = client.config.workspace_folders

      for _, ws in pairs(workspace or {}) do
        roots[#roots + 1] = vim.uri_to_fname(ws.uri)
      end

      if client.root_dir then
        roots[#roots + 1] = client.root_dir
      end
    end

    return vim.tbl_filter(function(path)
      path = M.norm(path)

      return path and buffer_path:find(path, 1, true) == 1
    end, roots)
  end,

  --- Detect the root using a specific pattern.
  ---
  --- ### Example:
  --- ```lua
  --- M.detectors.pattern(1, { ".git" }) -- { "/Users/flashios09/.config/nvim/" }
  --- M.detectors.pattern(2, { "package.json" }) -- { "/path/to/node/project/" }
  --- ```
  ---@param buffer number The buffer number, e.g. `1`.
  ---@param patterns string[]|string Patterns or filenames to search for, e.g. `".git"`, `{ ".git", "package.json", "*.mod" }`
  ---@return table|table<string> A string table paths, empty table otherwise.
  pattern = function(buffer, patterns)
    if type(patterns) == "string" then
      patterns = { patterns }
    end

    local path = M.bufpath(buffer) or vim.uv.cwd()
    local pattern = vim.fs.find(function(name)
      for _, p in ipairs(patterns) do
        if name == p then
          return true
        end

        if p:sub(1, 1) == "*" and name:find(vim.pesc(p:sub(2)) .. "$") then
          return true
        end
      end

      return false
    end, { path = path, upward = true })[1]

    return pattern and { vim.fs.dirname(pattern) } or {}
  end,
}

--- Root cache table.
---
--- Used to cache the root for each buffer.
---
--- ### Example:
--- ```lua
--- M.cache -- { 1 = "/Users/flashios09/.config/nvim/", 2 = "..." }
--- ```
---@type table<number, string>
M.cache = {}

--- Get the `root` of the passed `buffer` from the cache.
---
--- ### Example:
--- ```lua
--- M.getCache(1) -- `"/Users/flashios09/.config/nvim/"`
--- ```
---@param buffer number The `buffer`, e.g. `1`.
---@return string|nil The `root` of the passed `buffer` if found, `nil` otherwise.
function M.getCache(buffer)
  return M.cache[buffer]
end

--- Set the `root` of the passed `buffer` in the cache.
---
--- ### Example:
--- ```lua
--- M.setCache(1, "/Users/flashios09/.config/nvim/")
--- ```
---@param buffer number The `buffer`, e.g. `1`.
---@param root string The `root`, e.g. `"/Users/flashios09/.config/nvim/"`.
function M.setCache(buffer, root)
  M.cache[buffer] = root
end

--- Get the current working directory.
---
---@param buffer? number|nil The `buffer`, e.g. `1`.
---@return string The current working directory.
function M.cwd(buffer)
  buffer = (buffer == nil or buffer == 0) and vim.api.nvim_get_current_buf() or buffer
  local cwd = nil
  local vim_cwd = vim.uv.cwd()
  local root = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(assert(buffer)), ":h")

  if root == vim_cwd then
    -- root is vim_cwd
    cwd = vim_cwd
  elseif vim_cwd and root:find(vim_cwd, 1, true) == 1 then
    -- root is subdirectory of vim_cwd
    cwd = vim_cwd
  elseif vim_cwd and vim_cwd:find(root, 1, true) == 1 then
    -- root is parent directory of vim_cwd
    cwd = root
  else
    -- root and cwd are not related
    cwd = root
  end

  return M.realpath(cwd) or ""
end

--- Get the buffer path.
---
--- ### Example:
--- ```lua
--- M.bufpath(1) -- `"/Users/flashios09/.config/nvim/"`
--- ```
---@param buffer number The buffer number, e.g. `1`.
---@return string|nil The buffer path, nil otherwise, e.g. `"/Users/flashios09/.config/nvim/"`.
function M.bufpath(buffer)
  return M.realpath(vim.api.nvim_buf_get_name(assert(buffer)))
end

--- Get and normalize the path.
---
--- ### Example:
--- ```lua
--- M.realpath("~/.config/nvim/") -- `"/Users/flashios09/.config/nvim/"`
--- M.realpath("C:\.config\nvim\") -- `"C:/.config/nvim/"`
--- ```
---@param path string|nil The buffer path, e.g. `"~/.config/nvim/"`.
---@return string|nil The normalized buffer path, `nil` otherwise, e.g. `"/Users/flashios09/.config/nvim/"`.
function M.realpath(path)
  if path == "" or path == nil then
    return nil
  end

  path = vim.uv.fs_realpath(path) or path

  return M.norm(path)
end

--- Normalize the buffer path.
---
--- - Replace the `~` with the users home dir.
--- - Normalize the windows path(the directory separator): replace the `\` with `/`.
---
--- ### Example:
--- ```lua
--- M.norm("~/.config/nvim/") -- `"/Users/flashios09/.config/nvim/"`
--- M.norm("C:\.config\nvim\") -- `"C:/.config/nvim/"`
--- ```
---@param path string The buffer path, e.g. `"~/.config/nvim/"`.
---@return string The normalized buffer path, e.g. `"/Users/flashios09/.config/nvim/"`
function M.norm(path)
  if path:sub(1, 1) == "~" then
    local home = vim.uv.os_homedir()

    if home == nil then
      return path
    end

    if home:sub(-1) == "\\" or home:sub(-1) == "/" then
      home = home:sub(1, -2)
    end

    path = home .. path:sub(2)
  end

  path = path:gsub("\\", "/"):gsub("/+", "/")

  return path:sub(-1) == "/" and path:sub(1, -2) or path
end

--- Get the root function depending of the passed spec(s).
---
--- ### Example:
--- ```
--- M.resolve("cwd") -- `function() return { vim.uv.cwd() } end`
--- ```
---@param spec RootSpec The root spec, e.g. `cwd`, `lsp` ...
---@return RootFn The root function, e.g. `function() return { vim.uv.cwd() } end`.
function M.resolve(spec)
  if M.detectors[spec] then
    return M.detectors[spec]
  end

  if type(spec) == "function" then
    return spec
  end

  return function(buffer)
    return M.detectors.pattern(buffer, spec)
  end
end

--- Get all the available root spec(s).
---
--- ### Example
--- ```lua
--- M.detect()
--- -- output:
--- {
---   {
---     paths = { "/Users/flashios09/.config/nvim" },
---     spec = "lsp"
---   }, {
---     paths = { "/Users/flashios09/.config/nvim" },
---     spec = { ".git", "lua" }
---   }, {
---     paths = { "/Users/flashios09/.config/nvim" },
---     spec = "cwd"
---   }
--- }
--- ```
---@param options? { buffer?: number, spec?: RootSpec[], all?: boolean } The options table.
---@return M[] The root table.
function M.detect(options)
  options = options or {}
  options.spec = options.spec or type(vim.g.root_spec) == "table" and vim.g.root_spec or M.default_spec
  options.buffer = (options.buffer == nil or options.buffer == 0) and vim.api.nvim_get_current_buf() or options.buffer

  local result = {} ---@type M[]
  for _, spec in ipairs(options.spec) do
    local paths = M.resolve(spec)(options.buffer)
    paths = paths or {}
    paths = type(paths) == "table" and paths or { paths }
    local roots = {} ---@type string[]

    for _, p in ipairs(paths) do
      ---@diagnostic disable-next-line: param-type-mismatch
      local pp = M.realpath(p)

      if pp and not vim.tbl_contains(roots, pp) then
        roots[#roots + 1] = pp
      end
    end

    table.sort(roots, function(a, b)
      return #a > #b
    end)

    if #roots > 0 then
      result[#result + 1] = { spec = spec, paths = roots }
      if options.all == false then
        break
      end
    end
  end

  return result
end

--- Return the `buffer` root directory.
---
--- Based on:
--- - lsp workspace folders
--- - lsp root_dir
--- - root pattern of filename of the current buffer
--- - root pattern of cwd
---
--- ### Example:
--- ```lua
--- M.get() -- `"/Users/flashios09/.config/nvim/"`
--- M.get({ buffer = 1 }) -- `"/Users/flashios09/.config/nvim/"`
--- ```
---@param options? {buffer?: number} The `options` table, e.g. `{ buffer = 1 }`.
---@return string The `root`, e.g. `"/Users/flashios09/.config/nvim/"`.
function M.get(options)
  options = options or {}
  local buffer = options.buffer or vim.api.nvim_get_current_buf()
  local cached_root = M.getCache(buffer)

  if cached_root then
    return cached_root
  end

  local roots = M.detect({ all = false, buffer = buffer })
  local root = roots[1] and roots[1].paths[1] or vim.uv.cwd()

  M.setCache(buffer, root)

  return jit.os:find("Windows") and root:gsub("/", "\\") or root
end

--- Get the git root path if exists.
---
--- ### Example:
--- ```lua
--- M.git() -- `"/Users/flashios09/.config/nvim/"`
--- ```
---@return string The git root path if exists, the `root` path otherwise.
function M.git()
  local root = M.get()
  local git_root = vim.fs.find(".git", { path = root, upward = true })[1]
  local result = git_root and vim.fn.fnamemodify(git_root, ":h") or root

  return result
end

return M
