# Module: neovim – the editor, preconfigured, and the default editor ($EDITOR). Its colours are the guest look's
# (/etc/omaflake/look/nvim.lua, omaflake's platform); its keys the recipe's.
{ lib, pkgs, settings, omaflake, ... }:

let
  # The recipe's keys in Neovim's notation
  k = lib.mapAttrs (_: omaflake.keyLib.neovim) omaflake.keys;
in
{
  environment.systemPackages = [ pkgs.neovim ]; # plain nvim for root; the user gets the configured one
  environment.variables.EDITOR = "nvim";

  home-manager.users.${settings.user} = {
    programs.neovim = {
      enable = true;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;
      withRuby = false;
      withPython3 = false;
      plugins = with pkgs.vimPlugins; [
        nvim-web-devicons
        lualine-nvim
        bufferline-nvim
        # grammars via p.<name>: kept explicit, so no `with p;` can shadow names in scope
        (nvim-treesitter.withPlugins (p: map (n: p.${n}) [
          "bash" "c" "go" "javascript" "json" "lua" "markdown" "markdown_inline"
          "nix" "python" "rust" "toml" "typescript" "vim" "vimdoc" "yaml"
        ]))
        indent-blankline-nvim
        gitsigns-nvim
        which-key-nvim
        telescope-nvim
        telescope-fzf-native-nvim
        plenary-nvim
        neo-tree-nvim
        nui-nvim
        nvim-autopairs
        alpha-nvim
        nvim-lspconfig   # language server configurations: other modules enable theirs (vim.lsp.enable)
      ];
      initLua = ''
        -- Basics
        vim.g.mapleader = " "
        vim.g.maplocalleader = " "
        local o = vim.opt
        o.number = true
        o.relativenumber = true
        o.termguicolors = true
        o.mouse = "a"
        o.clipboard = "unnamedplus"   -- wl-clipboard
        o.cursorline = true
        o.signcolumn = "yes"
        o.scrolloff = 8
        o.expandtab = true
        o.shiftwidth = 2
        o.tabstop = 2
        o.ignorecase = true
        o.smartcase = true
        o.splitright = true
        o.splitbelow = true
        o.undofile = true
        o.showmode = false            -- shown in lualine
        o.laststatus = 3

        -- Look: the guest's (omaflake's platform) – sets the colours, returns lualine's theme
        local look_ok, lualine_theme = pcall(dofile, "/etc/omaflake/look/nvim.lua")
        if not look_ok then lualine_theme = "auto" end
        require("lualine").setup({ options = { theme = lualine_theme, globalstatus = true,
          component_separators = "", section_separators = { left = "", right = "" } } })
        require("bufferline").setup({ options = { diagnostics = false, separator_style = "slant",
          offsets = { { filetype = "neo-tree", text = "Files", separator = true } } } })
        require("ibl").setup({ indent = { char = "│" }, scope = { enabled = true } })
        require("gitsigns").setup()
        require("nvim-autopairs").setup()
        require("which-key").setup()
        require("neo-tree").setup({ close_if_last_window = true,
          filesystem = { follow_current_file = { enabled = true } } })

        -- Start screen
        local dashboard = require("alpha.themes.dashboard")
        dashboard.section.header.val = { "", "  N E O V I M", "" }
        dashboard.section.buttons.val = {
          dashboard.button("f", "  Find file", ":Telescope find_files<CR>"),
          dashboard.button("g", "  Find text", ":Telescope live_grep<CR>"),
          dashboard.button("r", "  Recent files", ":Telescope oldfiles<CR>"),
          dashboard.button("e", "  New file", ":ene <BAR> startinsert<CR>"),
          dashboard.button("q", "  Quit", ":qa<CR>"),
        }
        require("alpha").setup(dashboard.config)

        -- Search
        local telescope = require("telescope")
        telescope.setup({ defaults = { prompt_prefix = "   ", selection_caret = " " } })
        pcall(telescope.load_extension, "fzf")

        -- Treesitter (nvim-treesitter main: parsers from Nix, highlighting via the Neovim API)
        vim.api.nvim_create_autocmd("FileType", {
          callback = function(args)
            if pcall(vim.treesitter.start, args.buf) then
              vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
            end
          end,
        })

        -- Key bindings: the recipe's (module.toml's defaults and the recipe's key bindings); leader = space
        local map = vim.keymap.set
        local tb = require("telescope.builtin")
        map("n", "${k.find-files}", tb.find_files, { desc = "Find files" })
        map("n", "${k.find-text}", tb.live_grep,  { desc = "Find text" })
        map("n", "${k.buffers}", tb.buffers,    { desc = "Buffers" })
        map("n", "${k.help}", tb.help_tags,  { desc = "Help" })
        map("n", "${k.file-tree}", "<cmd>Neotree toggle<CR>", { desc = "File tree" })
        map("n", "${k.next-buffer}", "<cmd>BufferLineCycleNext<CR>", { desc = "Next buffer" })
        map("n", "${k.previous-buffer}", "<cmd>BufferLineCyclePrev<CR>", { desc = "Previous buffer" })
        map("n", "${k.save}", "<cmd>w<CR>", { desc = "Save" })
        map("n", "${k.close}", "<cmd>q<CR>", { desc = "Close" })
        map("n", "<Esc>", "<cmd>nohlsearch<CR>")
      '';
    };
  };
}
