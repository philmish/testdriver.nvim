local drivers = {
    ["go"] = function(args)
        local opts = args or {}
    end,
    ["javascript"] = function(args)
        local opts = args or {}
    end,
    ["php"] = function (args)
        local opts = args or {}
        local driver = require"drivers.php_d"
        driver.setup(opts)
        return driver
    end,
    ["python"] = function (args)
        local opts = args or {}
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

vim.api.nvim_create_user_command("tdTest", function ()
    local driver = load_driver(vim.bo.filetype, {})
    if not driver then
        vim.notify(
            {"Couldnt load test driver for current file type ", vim.bo.filetype},
            vim.log.levels.ERROR
        )
        return
    end
    if not driver.run_test then
        vim.notify(
            {"Current driver ", vim.bo.filetype, " does not implement running tests."},
            vim.log.levels.ERROR
        )
        return
    end
    driver.run_test()
end)
