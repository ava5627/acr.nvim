# acr.nvim

A quickrun plugin with [toggleterm](https://github.com/akinsho/toggleterm.nvim) and [DAP](https://github.com/mfussenegger/nvim-dap/) integration.

## installation
Use plugin manager of your choice

packer.nvim
```
use("austin5627/acr.nvim")
```
vim-plug
```vim
Plug "austin5627/acr.nvim"
```

## Configuration


Default configuration
```lua
require("acr").setup({
    -- Default commands for specific file types
    -- Supports variable substitution: %, #, $file, $altFile, $dir, $filePath, $fileBase, $moduleName from jaq
    cmds = {
        python = "python3 %",
        go = "go run %",
        java = "java %",
    },
    term_opts = {
        -- accepts all options for toggleterm custom-terminals
        direction = "horizontal", -- accepts all toggleterm values but float and tab are disabled when executing multiple commands
        close_on_exit = false,
        hidden = false,
    },
    json_filename = "run.json" -- name of json file containing workspace specific configuration
})
```

### term_opts
The configuration options for [toggleterm custom terminals](https://github.com/akinsho/toggleterm.nvim#custom-terminals)

## run.json

If a file with the name configured from `json_filename` exists in the current working directory, it will be searched for configurations

Each launch configuration is an element in a `configurations` list.

Each configuration can have the following attributes:

- `name`: [string], the name of the configuration.
- `default`: [boolean] if true then `ACRAuto` will run this configuration
- `command`: [string or list] string containing the command to run your program or a list of multiple commands to be run simultaneously
- `args`: [string or list] a string containing arguments for the program or a list of multiple arguments that will be concatenated together with a space.
    - if both `command` and `args` are lists, the ith element will be appended to the ith element in `command`
        - Each element of `args` can be either a string or a list of arguments
    - if `command` is a list and `args` is a string, `args` will be appended to all commands
- `cwd`: [string] directory the program should be run from
- `env`: [dict or list] dict of environment variables and values passed to the program of the form `"variable": "value"`
    - if `command` is a list and `env` is a list the ith element will be passed to the ith element in `command`
    - if `command` is a list and `env` is a dict the same environment variables will be passed all commands
- `term_opts` [dict] custom terminal options, same values as in config

`command` and `args` also accept variable substitution

if a configuration has the `debug` attribute set to true and Nvim-DAP is installed then the configuration will be run with DAP as a DAP configuration

see `h: dap-launch.json`, `h: dap-configuration` and [the DAP wiki](https://github.com/mfussenegger/nvim-dap/wiki/Debug-Adapter-installation) for the values that accepts.

Example config
```json
{
    "configurations": [
        {
            "command": "python main.py",
            "name": "Run main.py",
            "args": "arg1 arg2",
            "env": {
                "var": "value",
                "var2": "value"
            },
            "term_opts": {
                "direction": "float"
            },
            "default": true
        },
        {
            "command": "python other.py",
            "name": "Run other.py"
            "args": ["otherarg1", "otherarg2"]
        },
        {
            "command":[
                "python main.py",
                "python other.py"
            ],
            "name": "Run both side by side",
            "env": [
                { "var": "value" },
                { "othervar": "value" }
            ],
            "args": [
                "arg1 arg2",
                ["arg1", "arg2"]
            ]
        },
        {
            "type": "python",
            "request": "launch",
            "name": "Debug main.py",
            "program": "main.py",
            "debug": true
        },
    ]
}
```

## Usage

`:ACR` and `require("acr").ACR` will search default commands and json file for a run configuration. If several exist the user will be prompted to choose.

`:ACRAuto` and `require("acr").ACRAuto` look for a configuration with default set to true or a default command for the current filetype and runs it.

Example keymapping
```lua
kmap("n", "<leader>t", require("acr").ACRAuto, opts)
kmap("n", "<leader>r", require("acr").ACR, opts)
```
