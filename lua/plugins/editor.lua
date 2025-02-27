return {
    {
        'nvim-telescope/telescope.nvim',
        tag = '0.1.8',
        lazy = false,
        dependencies = { 'nvim-lua/plenary.nvim' },
    },
    {
        "nvim-treesitter/nvim-treesitter",
        dependencies = {
            'nvim-treesitter/nvim-treesitter-textobjects',
        },
        build = ":TSUpdate",
        opts = {
            ensure_installed = {
                "go",
                "lua",
                "regex",
                "typescript",
                "javascript",
                "json",
                "yaml",
                "markdown",
                "diff",
                "tsx",
                "sql",
            },
            sync_install = false,
            highlight = { enable = true },
            indent = { enable = true },
        },
        config = function(_, opts)
            if type(opts.ensure_installed) == "table" then
                --opts.ensure_installed = LazyVim.dedup(opts.ensure_installed)
            end
            require("nvim-treesitter.configs").setup(opts)
        end,
    },
    {
        'nvim-treesitter/nvim-treesitter-textobjects',
        lazy = true,
        config = function()
            require("nvim-treesitter.configs").setup({
                textobjects = {
                    select = {
                        enable = true,
                        lookahead = true,
                        keymaps = {
                            ["af"] = { query = "@function.outer", desc = "select outer part of function" },
                            ["if"] = { query = "@function.inner", desc = "select inner part of function" },
                            ["aa"] = { query = "@parameter.outer", desc = "select outer part of parameter" },
                            ["ia"] = { query = "@parameter.inner", desc = "select inner part of parameter" },
                        },
                    },
                    move = {
                        enable = true,
                        set_jumps = true,
                        goto_next_start = {
                            ["]a"] = { query = "@parameter.inner", desc = "next param" },
                        },
                    }
                },
            })
        end
    },

    {
        "neovim/nvim-lspconfig",
        event = { "BufReadPre", "BufNewFile" },
        opts = {
            diagnostics = {
                underline = true,
                update_in_insert = false,
                virtual_text = {
                    spacing = 4,
                    source = "if_many",
                    prefix = "●",
                },
                severity_sort = true,
            },
            -- add any global capabilities here
            capabilities = {},
            -- Automatically format on save
            autoformat = true,
            -- options for vim.lsp.buf.format
            -- `bufnr` and `filter` is handled by the LazyVim formatter,
            -- but can be also overridden when specified
            format = {
                formatting_options = nil,
                timeout_ms = nil,
            },
            servers = {
                gopls = {
                    settings = {
                        gopls = {
                            gofumpt = true,
                            codelenses = {
                                gc_details = false,
                                generate = true,
                                regenerate_cgo = true,
                                run_govulncheck = true,
                                test = true,
                                tidy = true,
                                upgrade_dependency = true,
                                vendor = true,
                            },
                            hints = {
                                assignVariableTypes = true,
                                compositeLiteralFields = true,
                                compositeLiteralTypes = true,
                                constantValues = true,
                                functionTypeParameters = true,
                                parameterNames = true,
                                rangeVariableTypes = true,
                            },
                            analyses = {
                                nilness = true,
                                unusedparams = true,
                                unusedwrite = true,
                                useany = true,
                            },
                            usePlaceholders = true,
                            completeUnimported = true,
                            staticcheck = true,
                            directoryFilters = { "-.git", "-.vscode", "-.idea", "-.vscode-test", "-node_modules" },
                            semanticTokens = true,
                        }
                    }
                },
                lua_ls = {
                    mason = false, -- set to false if you don't want this server to be installed with mason
                    -- Use this to add any additional keymaps
                    -- for specific lsp servers
                    -- ---@type LazyKeysSpec[]
                    -- keys = {},
                    settings = {
                        Lua = {
                            format = {
                                enable = true,
                                defaultConfig = {
                                    indent_style = "space",
                                    indent_size = "2",
                                }
                            },
                            workspace = {
                                checkThirdParty = false,
                            },
                            codeLens = {
                                enable = true,
                            },
                            completion = {
                                callSnippet = "Replace",
                            },
                            doc = {
                                privateName = { "^_" },
                            },
                            hint = {
                                enable = true,
                                setType = false,
                                paramType = true,
                                paramName = "Disable",
                                semicolon = "Disable",
                                arrayIndex = "Disable",
                            },
                        },
                    },
                    on_attach = function(client, bufnr)
                        vim.keymap.set('n', '<leader>fm', function()
                            local params = vim.lsp.util.make_formatting_params({})
                            local handler = function(err, result)
                                if not result then return end

                                vim.lsp.util.apply_text_edits(result, bufnr, client.offset_encoding)
                                vim.cmd('write')
                            end

                            client.request('textDocument/formatting', params, handler, bufnr)
                        end, { buffer = bufnr })
                    end,
                },
            },
            setup = {
                gopls = function(_, opts)
                    vim.api.nvim_create_autocmd("LspAttach", {
                        callback = function(args)
                            local client = vim.lsp.get_client_by_id(args.data.client_id)
                            if not client.server_capabilities.semanticTokensProvider then
                                local semantic = client.config.capabilities.textDocument.semanticTokens
                                client.server_capabilities.semanticTokensProvider = {
                                    full = true,
                                    legend = {
                                        tokenTypes = semantic.tokenTypes,
                                        tokenModifiers = semantic.tokenModifiers,
                                    },
                                    range = true
                                }
                            end
                        end
                    })
                    vim.api.nvim_create_autocmd("BufWritePre", {
                        pattern = "*.go",
                        callback = function()
                            local params = vim.lsp.util.make_range_params()
                            params.context = { only = { "source.organizeImports" } }
                            -- buf_request_sync defaults to a 1000ms timeout. Depending on your
                            -- machine and codebase, you may want longer. Add an additional
                            -- argument after params if you find that you have to write the file
                            -- twice for changes to be saved.
                            -- E.g., vim.lsp.buf_request_sync(0, "textDocument/codeAction", params, 3000)
                            local result = vim.lsp.buf_request_sync(0, "textDocument/codeAction", params)
                            for cid, res in pairs(result or {}) do
                                for _, r in pairs(res.result or {}) do
                                    if r.edit then
                                        local enc = (vim.lsp.get_client_by_id(cid) or {}).offset_encoding or "utf-16"
                                        vim.lsp.util.apply_workspace_edit(r.edit, enc)
                                    end
                                end
                            end
                            vim.lsp.buf.format({ async = false })
                        end
                    })
                end,
            },
        },
        config = function(_, opts)
            local servers = opts.servers
            local has_cmp, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
            --local has_blink, blink = pcall(require, "blink.cmp")
            local capabilities = vim.tbl_deep_extend(
                "force",
                {},
                vim.lsp.protocol.make_client_capabilities(),
                has_cmp and require("cmp_nvim_lsp").default_capabilities(),
                opts.capabilities or {}
            )

            local function setup(server)
                local server_opts = vim.tbl_deep_extend("force", {
                    capabilities = vim.deepcopy(capabilities),
                }, servers[server] or {})
                if opts.setup[server] then
                    if opts.setup[server](server, server_opts) then
                        return
                    end
                elseif opts.setup["*"] then
                    if opts.setup["*"](server, server_opts) then
                        return
                    end
                end
                require("lspconfig")[server].setup(server_opts)
            end

            for server, server_opts in pairs(servers) do
                if server_opts then
                    server_opts = server_opts == true and {} or server_opts
                    -- run manual setup if mason=false or if this is a server that cannot be installed with mason-lspconfig
                    setup(server)
                end
            end
            vim.api.nvim_create_autocmd("LspAttach", {
                group = vim.api.nvim_create_augroup("UserLspConfig", {}),
                callback = function(ev)
                    local opts = { buffer = ev.buf }
                    vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)
                    vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
                    vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
                    --vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)
                    --vim.keymap.set("n", "gr", vim.lsp.buf.references, opts) SEE telescope.lua
                    vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, opts)
                    vim.keymap.set("n", "]d", vim.diagnostic.goto_next, opts)
                    vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
                    vim.keymap.set("n", "<leader>rf", vim.lsp.buf.code_action, opts)
                    vim.keymap.set("n", "<leader>ed", vim.diagnostic.open_float, opts)
                end
            })
        end
    },
    -- Autocomplete and snippets
    {
        "hrsh7th/nvim-cmp",
        dependencies = {
            "hrsh7th/cmp-nvim-lsp",
            "hrsh7th/cmp-buffer",
            "hrsh7th/cmp-path",
            "hrsh7th/cmp-cmdline",
            "hrsh7th/nvim-cmp",
            {
                "L3MON4D3/LuaSnip",
                dependencies = {
                    "rafamadriz/friendly-snippets",
                    "saadparwaiz1/cmp_luasnip",
                },
            },
        },
        config = function()
            local cmp = require('cmp')
            local luasnip = require("luasnip")
            local utils = require("utils")

            luasnip.config.set_config({
                history = false,
                updateevents = "TextChanged,TextChangedI",
            })


            --            require("luasnip.loaders.from_vscode").load({ include = { "html" } })
            --          require("luasnip.loaders.from_vscode").lazy_load()
            cmp.setup({
                snippet = {
                    expand = function(args)
                        luasnip.lsp_expand(args.body)
                    end,
                },

                mapping = {
                    ['<Tab>'] = cmp.mapping(function(fallback)
                        if cmp.visible() then
                            cmp.select_next_item({ behavior = cmp.SelectBehavior.Select })
                        elseif utils.check_back_space() then
                            fallback()
                        else
                            cmp.complete()
                        end
                    end, { 'i', 's' }),

                    ['<S-Tab>'] = cmp.mapping(function(fallback)
                        if cmp.visible() then
                            cmp.select_prev_item({ behavior = cmp.SelectBehavior.Select })
                        elseif utils.check_back_space() then
                            fallback()
                        else
                            cmp.complete()
                        end
                    end, { 'i', 's' }),

                    ['<CR>'] = cmp.mapping.confirm({ select = true }),
                },

                -- Order of sources determines order of sourcing
                sources = cmp.config.sources({
                    { name = "nvim_lsp" },
                    { name = "treesitter" },
                    { name = "buffer" },
                    { name = "luasnip" },
                    { name = "nvim_lua" },
                    { name = "path" },
                }),
                window = {
                    completion = cmp.config.window.bordered(),
                    documentation = cmp.config.window.bordered(),
                },
            })
        end,
    },
    {
        "lukas-reineke/indent-blankline.nvim",
        main = "ibl",
        ---@module "ibl"
        ---@type ibl.config
        opts = {
            scope = {
                enabled = false }
        },
        config = function(_, opts)
            -- paste the hooks code here
            -- change the setup() call to:
            require("ibl").setup(opts)
        end
    },
    {
        'nvim-lualine/lualine.nvim',
        dependencies = { 'nvim-tree/nvim-web-devicons' },
        opts = { theme = "auto" }
    },
    {
        'akinsho/toggleterm.nvim',
        version = "*",
        config = function()
            require("toggleterm").setup({
                size = 10,
                open_mapping = [[<F7>]],
                shading_factor = 2,
                float_opts = {
                    highlights = {
                        border = "Normal",
                        background = "Normal",
                    },
                },
            })
            local Terminal = require("toggleterm.terminal").Terminal
            local lazygit = Terminal:new({
                cmd = "lazygit",
                dir = "git_dir",
                direction = "float",
                float_opts = {
                    border = "curved",
                    highlights = {
                        border = "Normal",
                        background = "Normal",
                    },
                },
                on_open = function(term)
                    vim.cmd("startinsert!")
                    vim.api.nvim_buf_set_keymap(term.bufnr, "n", "q", "<cmd>close<CR>", { noremap = true, silent = true })
                end,
                -- function to run on closing the terminal
                on_close = function(term)
                    vim.cmd("startinsert!")
                end,
                hidden = true
            })
            function _lazygit_toggle()
                lazygit:toggle()
            end

            vim.keymap.set("n", "<leader>g", "<cmd>lua_lazygit_toggle()<CR>", { noremap = true, silent = true })
        end,
    },
    {
        'nvim-neotest/neotest',
        tag = 'v5.6.1',
        dependencies = {
            'nvim-neotest/nvim-nio',
            'nvim-lua/plenary.nvim',
            'antoinemadec/FixCursorHold.nvim',
            'nvim-treesitter/nvim-treesitter',
            'nvim-neotest/neotest-go',
        },
        config = function()
            require('neotest').setup({
                adapters = {
                    require('neotest-go')({
                        args = { '-coverprofile=coverage.out' },
                    })
                },
            })
            vim.keymap.set('n', '<Leader>tt', ':lua require("neotest").run.run()<CR>', { desc = 'Run test' })
        end,
    }
}
