# Recipe: neovim-research – reading, writing, analysis (neovim line)
# LaTeX (TeX Live, full) and Typst with a live PDF beside the editor: neovim compiles on every save (vimtex +
# latexmk; for Typst `typst watch`), zathura shows the PDF next to it and reloads it; SyncTeX jumps between text and
# PDF (Ctrl+click in zathura → the line in neovim). Plus Python for analysis, pandoc.
{ config, lib, pkgs, settings, ... }:

let
  # The guest look's colours (omaflake's modules/look.nix; null for vanilla and in omaflake without looks)
  look = config.omaflake.lookColors or null;
in
{
  networking.hostName = "neovim-research";
  omaflake.editor = "neovim";

  environment.systemPackages = with pkgs; [
    (python3.withPackages (ps: with ps; [ numpy pandas matplotlib jupyterlab ]))
    texliveFull                # latexmk, biber, chktex, latexindent, every package
    texlab                     # LaTeX language server
    typst tinymist             # Typst and its language server
    zathura
    pandoc
  ];

  home-manager.users.${settings.user} = {
    # zathura in the look's colours (a dark look shows PDFs inverted in its colours), SyncTeX on; it reloads a PDF
    # when it changes
    programs.zathura = {
      enable = true;
      options = {
        synctex = true;
        selection-clipboard = "clipboard";
      } // lib.optionalAttrs (look != null) {
        default-bg = "#${look.base}";
      } // lib.optionalAttrs (look != null && look.dark) {
        recolor = true;
        recolor-keephue = true;
        recolor-darkcolor = "#${look.text}";
        recolor-lightcolor = "#${look.base}";
      };
    };

    programs.neovim = {
      plugins = with pkgs.vimPlugins; [ vimtex nvim-lspconfig ];
      initLua = lib.mkAfter ''
        -- research: LaTeX with vimtex, Typst with typst watch – both with zathura beside the editor
        vim.g.vimtex_view_method = "zathura"
        vim.g.vimtex_compiler_latexmk = { continuous = 1 }   -- compiles on every save
        vim.g.vimtex_quickfix_open_on_warning = 0
        -- Open a .tex file and press <space>ll: compile continuously and open the PDF; <space>lv jumps to the
        -- cursor's place in the PDF; Ctrl+click in zathura jumps back

        -- Typst: <space>tp compiles this file now and on every save and shows the PDF in zathura. Not `typst watch`:
        -- it and zathura's reload rely on file change events, which the share folder (/mnt/share, 9p) does not
        -- deliver. So neovim compiles on save into ~/.cache/typst/<name>.pdf, which zathura shows, and copies the
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
                if open then vim.fn.jobstart({ "zathura", view }, { detach = true }) end
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
        vim.keymap.set("n", "<leader>tp", typst_live, { desc = "Typst: PDF in zathura, compiled on save" })

        -- Language servers: texlab (LaTeX), tinymist (Typst)
        vim.lsp.enable({ "texlab", "tinymist" })
      '';
    };
  };
}
