local ns = vim.api.nvim_create_namespace("test-driver")
local group = vim.api.nvim_create_augroup("test-driver", { clear = true })

local drivers = {
    ["go"] = function(args)
        local opts = args or {}
        local driver = require"drivers.go_d"
        driver.setup(opts)
        return driver
    end,
    ["javascript"] = function(args)
        local opts = args or {}
        local driver = require"drivers.js_d"
        driver.setup(opts)
        return driver
    end,
    ["php"] = function (args)
        local opts = args or {}
        local driver = require"drivers.php_d"
        driver.setup(opts)
        return driver
    end,
    ["python"] = function (args)
        local opts = args or {}
        local driver = require"drivers.python_d"
        driver.setup(opts)
        return driver
    end,
}

local function load_driver(name, opts)
    if not name then
        return nil
    end
    if drivers[name] then
        return drivers[name](opts)
    end
    return nil
end

vim.api.nvim_create_user_command("TestDriver", function ()
   local driver = load_driver(vim.bo.filetype, {})
    if not driver then
        vim.notify(
            "Couldnt load test driver for current file type " .. vim.bo.filetype,
            vim.log.levels.ERROR
        )
        return
    end
    if not driver.attach then
        vim.notify(
            "Current driver " .. vim.bo.filetype .. " does not implement attaching to buffer.",
            vim.log.levels.ERROR
        )
        return
    end
    driver.attach(vim.api.nvim_get_current_buf(), ns, group)
end, {})
