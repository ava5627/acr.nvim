---@diagnostic disable: missing-parameter
-- Based off https://github.com/is0n/jaq-nvim to work with toggleterm and DAP



local config = {
    cmds = {
        markdown = "glow %",
        python = "python3 %",
        go = "go run %",
        java = "java %",
        sh = "%"
    },
    term_opts = {
        direction = "horizontal",
        close_on_exit = false,
        hidden = false,
    },
    json_filename = "run.json"
}

M = {}

-- stolen from https://github.com/is0n/jaq-nvim
local function substitute(cmd)
    cmd = cmd:gsub("%%", (vim.fn.expand("%"):gsub(" ", "\\ ")))
    cmd = cmd:gsub("$fileBase", (vim.fn.expand("%:r"):gsub(" ", "\\ ")))
    cmd = cmd:gsub("$filePath", (vim.fn.expand("%:p"):gsub(" ", "\\ ")))
    cmd = cmd:gsub("$file", (vim.fn.expand("%"):gsub(" ", "\\ ")))
    cmd = cmd:gsub("$dir", (vim.fn.expand("%:p:h"):gsub(" ", "\\ ")))
    cmd = cmd:gsub(
        "$moduleName",
        (vim.fn.substitute(
            vim.fn.substitute(vim.fn.fnamemodify(vim.fn.expand("%:r"), ":~:."), "/", ".", "g"),
            "\\",
            ".",
            "g"
        ):gsub(" ", "\\ "))
    )
    cmd = cmd:gsub("#", (vim.fn.expand("#"):gsub(" ", "\\ ")))
    cmd = cmd:gsub("$altFile", vim.fn.expand("#"))

    return cmd
end

local function get_cmd(configuration)
    if type(configuration) == "string" then
        return substitute(configuration)
    end
    local run_command = configuration.command
    if run_command == nil then
        return nil
    end
    local run_args = configuration.args or ""
    if type(run_command) == "table" then
        local full_cmd = {}
        for i, command in ipairs(run_command) do
            if type(run_args) == "table" and type(run_args[i]) == "string" then
                full_cmd[i] = substitute(command .. " " .. run_args[i])
            elseif type(run_args[i]) == "table" then
                full_cmd[i] = substitute(command .. " " .. table.concat(run_args[i], " "))
            else
                full_cmd[i] = substitute(command .. " " .. run_args)
            end
        end
        return full_cmd
    else
        if type(run_args) == "table" then
            run_args = table.concat(run_args, " ")
        end
        local full_cmd = run_command .. " " .. run_args
        return substitute(full_cmd)
    end
end

local function execInTerminal(term_opts)
    print(term_opts.size)
    local tt_status, toggleterm = pcall(require, "toggleterm.terminal")
    if tt_status then
        local Terminal = toggleterm.Terminal
        local term = Terminal:new(term_opts)
        term:toggle()
    else
        vim.notify("toggleterm not installed", vim.log.levels.ERROR)
    end
end

local function run_configuration(configuration, conf)
    if configuration == nil then
        return
    end
    if configuration.debug then
        local dap_status, dap = pcall(require, "dap")
        if not dap_status then
            vim.notify("DAP not found", vim.log.levels.WARN)
            return
        end
        local dap_config = dap.configurations[configuration.type][1]
        local debug_configuration = vim.tbl_deep_extend("keep", configuration, dap_config)
        dap.run(debug_configuration)
        return
    end
    local cmd = get_cmd(configuration)
    if type(cmd) == "string" then
        local term_opts = vim.tbl_deep_extend("force", conf.term_opts, { cmd = cmd })
        if configuration.term_opts then
            term_opts = vim.tbl_deep_extend("force", term_opts, configuration.term_opts)
        end
        if configuration.env ~= nil then
            term_opts.env = configuration.env
        end
        if configuration.cwd ~= nil then
            term_opts.dir = configuration.cwd
        end
        execInTerminal(term_opts)
    elseif type(cmd) == "table" then
        for i, c in ipairs(cmd) do
            local term_opts = vim.tbl_deep_extend("force", conf.term_opts, { cmd = c })
            if configuration.term_opts then
                term_opts = vim.tbl_deep_extend("force", term_opts, configuration.term_opts)
            end
            if term_opts.direction == "float" then
                term_opts.direction = "horizontal"
            end
            if configuration.env ~= nil then
                term_opts.env[i] = (#configuration.env == 0 and configuration.env[i]) or configuration.env
            end
            if configuration.cwd ~= nil then
                term_opts.dir[i] = configuration.cwd
            end
            execInTerminal(term_opts)
        end
    end
end

local function readFile(conf)
    local file = io.open(vim.fn.getcwd() .. "/" .. conf.json_filename, "r")
    if not file then
        return nil
    end
    local content = file:read("*all")
    file:close()
    local json = vim.fn.json_decode(content) or {}
    local configurations = json.configurations or {}
    if #configurations == 0 then
        return nil
    end
    if #configurations > 1 then
        local choices = {}
        local config_map = {}
        for i, item in pairs(configurations) do
            table.insert(choices, item.name or ("Configuration " .. i))
            config_map[item.name] = item
        end
        if vim.ui then
            vim.ui.select(choices, {}, function(choice)
                run_configuration(config_map[choice], conf)
            end)
            return "async"
        else
            local choice = vim.fn.inputlist(choices)
            if choice == 0 then
                return nil
            end
            run_configuration(configurations[choice], conf)
            return "sync"
        end
    end
    run_configuration(configurations[1], conf)
    return "sync"
end

function M.ACR()
    local cmd = readFile(config) or config.cmds[vim.bo.filetype]
    if not cmd then
        vim.notify(
            "No run command found for filetype " ..
            vim.bo.filetype .. ". Manually set one in " .. config.json_filename .. " or nvim config",
            vim.log.levels.ERROR
        )
        return
    elseif cmd == "async" or cmd == "sync" then
        return
    end

    run_configuration(cmd, config)
end

function M.ACRAuto()
    local file = io.open(vim.fn.getcwd() .. "/" .. config.json_filename, "r")
    if not file then
        local cmd = config.cmds[vim.bo.filetype]
        if not cmd then
            vim.notify(
                "No run command found for filetype " ..
                vim.bo.filetype .. ". Manually set one in " .. config.json_filename .. " or nvim config",
                vim.log.levels.ERROR
            )
            return nil
        end
        run_configuration(cmd, config)
        return nil
    end
    local content = file:read("*all")
    local json = vim.fn.json_decode(content) or {}
    local configurations = json.configurations or {}
    if #configurations == 0 then
        return nil
    elseif #configurations == 1 then
        run_configuration(configurations[1], config)
        return
    end
    for _, item in pairs(configurations) do
        if item.default then
            run_configuration(item, config)
            return
        end
    end
    vim.notify("No default configuration found, running first configuration. Set \"default\": true in " .. config.json_filename .. " to choose a default configuration", vim.log.levels.INFO)
    run_configuration(configurations[1], config)
end

function M.setup(user_config)
    config = vim.tbl_deep_extend("force", config, user_config)
    vim.api.nvim_create_user_command("ACR", M.ACR, {})
    vim.api.nvim_create_user_command("ACRAuto", M.ACRAuto, {})
end

return M
