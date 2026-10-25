# Module: typst – Typst and tinymist. With Neovim: the preview key (Space t p by default) compiles the file now and on
# every save and shows the PDF in the PDF viewer (zathura when it is there).
{ lib, pkgs, settings, omaflake, ... }:

let
  viewer = if omaflake.has "omaflake/zathura" then "zathura" else "xdg-open";
in
{
  environment.systemPackages = with pkgs; [ typst tinymist ];

  home-manager.users.${settings.user} = lib.mkIf (omaflake.has "omaflake/neovim") {
    programs.neovim = {
      initLua = lib.mkAfter ''
        -- Typst: the preview key compiles this file now and on every save and shows the PDF in zathura. Not `typst watch`:
        -- it and zathura's reload rely on file change events, which the share folder (/mnt/share, 9p) does not
        -- deliver. So neovim compiles on save into ~/.cache/typst/<name>.pdf, which the PDF viewer shows, and copies the
        -- PDF next to the source (on the share: there for the host too).
        local function typst_live()
          local buf = vim.api.nvim_get_current_buf()
          local src = vim.api.nvim_buf_get_name(buf)
          local cache = vim.fn.stdpath("cache") .. "/typst"
          vim.fn.mkdir(cache, "p")
          local view = cache .. "/" .. vim.fn.fnamemodify(src, ":t:r") .. ".pdf"
          local pdf = vim.fn.fnamemodify(src, ":r") .. ".pdf"
          local function compile(open)
            vim.fn.jobstart({ "typst", "compile", src, view }, {
              stderr_buffered = true,
              on_stderr = function(_, lines)
                local text = vim.trim(table.concat(lines, "\n"))
                if text ~= "" then vim.notify("typst: " .. text, vim.log.levels.WARN) end
              end,
              on_exit = function(_, code)
                if code ~= 0 then return end
                vim.uv.fs_copyfile(view, pdf)
                if open then vim.fn.jobstart({ "${viewer}", view }, { detach = true }) end
              end,
            })
          end
          compile(true)
          vim.api.nvim_create_autocmd("BufWritePost", {
            group = vim.api.nvim_create_augroup("typst-live-" .. buf, { clear = true }),
            buffer = buf,
            callback = function() compile(false) end,
          })
        end
        vim.keymap.set("n", "${omaflake.keyLib.neovim omaflake.keys.preview}", typst_live, { desc = "Typst: PDF beside the editor, compiled on save" })
        vim.lsp.enable("tinymist")
      '';
    };
  };
}
