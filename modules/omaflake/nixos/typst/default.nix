# SPDX-License-Identifier: MIT
# Module: typst – Typst and tinymist. With Neovim: the preview key (Space t p by default) compiles the document now and on
# every save and shows the PDF in the PDF viewer (zathura when it is there). Multi-file projects work: the document is
# the main file that includes the current one (found upwards), the project folder is that file's folder.
{ lib, pkgs, settings, omaflake, ... }:

let
  viewer = if omaflake.has "omaflake/zathura" then "zathura" else "xdg-open";
in
{
  environment.systemPackages = with pkgs; [ typst tinymist ];

  home-manager.users.${settings.user} = lib.mkIf (omaflake.has "omaflake/neovim") {
    programs.neovim = {
      initLua = lib.mkAfter ''
        -- Typst: the main file of a document is the file that includes the current one (`include "…"`), followed
        -- upwards until no file includes it; without one the current file is its own main file. Candidates are the .typ
        -- files in the current file's folder and its parents; the search stops at a folder with .git, at the home
        -- folder, at the share folder (/mnt/share) and after ten folders. The project folder (typst --root, tinymist's
        -- root) is the main file's folder, so "/lib/x.typ" in a chapter resolves from there.
        local function typst_boundary(dir)
          return dir == "/" or dir == "/mnt/share" or dir == vim.uv.fs_realpath(vim.uv.os_homedir() or "/")
            or vim.uv.fs_stat(dir .. "/.git") ~= nil
        end

        -- Whether `cand` includes `file` (both real paths). Relative paths resolve from cand's folder; paths starting
        -- with "/" from the project folder, which is unknown here: any folder above cand counts.
        local function typst_includes(cand, file)
          local ok, lines = pcall(vim.fn.readfile, cand)
          if not ok then return false end
          local dir = vim.fs.dirname(cand)
          for _, line in ipairs(lines) do
            if not line:match("^%s*//") then
              for path in line:gmatch('%f[%w_]include%s*"([^"]+)"') do
                if path:sub(1, 1) == "/" then
                  local prefix = file:sub(1, #file - #path)
                  if file:sub(-#path) == path and cand:sub(1, #prefix + 1) == prefix .. "/" then return true end
                elseif vim.uv.fs_realpath(dir .. "/" .. path) == file then
                  return true
                end
              end
            end
          end
          return false
        end

        local function typst_includer(file)
          local dir = vim.fs.dirname(file)
          for _ = 1, 10 do
            local names = {}
            for name, kind in vim.fs.dir(dir) do
              if (kind == "file" or kind == "link") and name:match("%.typ$") then names[#names + 1] = name end
            end
            table.sort(names)
            for _, name in ipairs(names) do
              local cand = vim.uv.fs_realpath(dir .. "/" .. name)
              if cand and cand ~= file and typst_includes(cand, file) then return cand end
            end
            local parent = vim.fs.dirname(dir)
            if typst_boundary(dir) or parent == dir then return nil end
            dir = parent
          end
        end

        local function typst_main(src)
          local main = vim.uv.fs_realpath(src) or src
          local seen = { [main] = true }
          while true do
            local up = typst_includer(main)
            if not up or seen[up] then return main end
            seen[up] = true
            main = up
          end
        end

        -- The preview key compiles the document now and on every save of one of its files and shows the PDF in zathura.
        -- Not `typst watch`: it and zathura's reload rely on file change events, which the share folder (/mnt/share,
        -- 9p) does not deliver. So neovim compiles on save into ~/.cache/typst/<main>.pdf, which the PDF viewer shows,
        -- and copies the PDF next to the main file (on the share: there for the host too). A save recompiles when the
        -- file is one the last compile read (typst --deps: chapters, imports, bibliography); before that every .typ
        -- file below the project folder counts. One autocommand group per main file.
        local function typst_live()
          local src = vim.api.nvim_buf_get_name(0)
          if src == "" then return vim.notify("typst: save the file first", vim.log.levels.WARN) end
          local main = typst_main(src)
          local root = vim.fs.dirname(main)
          local cache = vim.fn.stdpath("cache") .. "/typst"
          vim.fn.mkdir(cache, "p")
          local name = vim.fn.fnamemodify(main, ":t:r")
          local view = cache .. "/" .. name .. ".pdf"
          local deps = cache .. "/" .. name .. ".deps.json"
          local pdf = vim.fn.fnamemodify(main, ":r") .. ".pdf"
          local inputs
          local function compile(open)
            vim.fn.jobstart({ "typst", "compile", "--root", root, "--deps", deps, main, view }, {
              cwd = root,
              stderr_buffered = true,
              on_stderr = function(_, lines)
                local text = vim.trim(table.concat(lines, "\n"))
                if text ~= "" then vim.notify("typst: " .. text, vim.log.levels.WARN) end
              end,
              on_exit = function(_, code)
                local ok, data = pcall(function() return vim.json.decode(table.concat(vim.fn.readfile(deps), "\n")) end)
                if ok and type(data) == "table" and type(data.inputs) == "table" then
                  inputs = {}
                  for _, p in ipairs(data.inputs) do
                    local abs = p:sub(1, 1) == "/" and p or root .. "/" .. p
                    inputs[vim.uv.fs_realpath(abs) or abs] = true
                  end
                end
                if code ~= 0 then return end
                vim.uv.fs_copyfile(view, pdf)
                if open then vim.fn.jobstart({ "${viewer}", view }, { detach = true }) end
              end,
            })
          end
          compile(true)
          vim.api.nvim_create_autocmd("BufWritePost", {
            group = vim.api.nvim_create_augroup("typst-live:" .. main, { clear = true }),
            callback = function(ev)
              local file = vim.api.nvim_buf_get_name(ev.buf)
              file = vim.uv.fs_realpath(file) or file
              local ours
              if inputs then ours = inputs[file] else ours = file:sub(1, #root + 1) == root .. "/" and file:match("%.typ$") end
              if ours then compile(false) end
            end,
          })
        end
        vim.keymap.set("n", "${omaflake.keyLib.neovim omaflake.keys.preview}", typst_live, { desc = "Typst: PDF beside the editor, compiled on save" })

        -- tinymist: the project folder is the main file's folder, and the main file is pinned, so chapters see the
        -- labels, imports and bibliography of the whole document.
        vim.lsp.config("tinymist", {
          root_dir = function(bufnr, on_dir)
            local src = vim.api.nvim_buf_get_name(bufnr)
            on_dir(src ~= "" and vim.fs.dirname(typst_main(src)) or vim.fn.getcwd())
          end,
        })
        vim.api.nvim_create_autocmd("LspAttach", {
          group = vim.api.nvim_create_augroup("typst-pin-main", { clear = true }),
          callback = function(ev)
            local client = vim.lsp.get_client_by_id(ev.data.client_id)
            local src = vim.api.nvim_buf_get_name(ev.buf)
            if not client or client.name ~= "tinymist" or src == "" then return end
            client:exec_cmd({ title = "Pin main", command = "tinymist.pinMain", arguments = { typst_main(src) } }, { bufnr = ev.buf })
          end,
        })
        vim.lsp.enable("tinymist")
      '';
    };
  };
}
