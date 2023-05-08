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

vim.api.nvim_create_user_command("TdTest", function ()
    vim.notify = require"notify"
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
end, {})

vim.api.nvim_create_user_command("TdWithCov", function ()
    vim.notify = require"notify"
    local driver = load_driver(vim.bo.filetype, {})
    if not driver then
        vim.notify(
            {"Couldnt load test driver for current file type ", vim.bo.filetype},
            vim.log.levels.ERROR
        )
        return
    end
    if not driver.with_coverage then
        vim.notify(
            {"Current driver ", vim.bo.filetype, " does not implement running tests with coverage."},
            vim.log.levels.ERROR
        )
        return
    end
    driver.with_coverage()
end, {})

vim.api.nvim_create_user_command("TdOutSplit", function ()
    local driver = load_driver(vim.bo.filetype, {})
    if not driver then
        vim.notify(
            {"Couldnt load test driver for current file type ", vim.bo.filetype},
            vim.log.levels.ERROR
        )
        return
    end
    if not driver.get_output then
        vim.notify(
            {"Cant open split for current driver. No getter function implemented for ", vim.bo.filetype},
            vim.log.levels.ERROR
        )
        return
    end
    local pre_win = vim.api.nvim_get_current_win()
    vim.opt.splitright = true
    vim.cmd("vnew")

    local win = vim.api.nvim_get_current_win()
    local bufnr = vim.api.nvim_create_buf(true, true)
    vim.api.nvim_win_set_buf(win, bufnr)
    vim.api.nvim_set_current_win(pre_win)
    vim.api.nvim_buf_set_lines(bufnr, 0, 0, false, driver.get_output())
end, {})
