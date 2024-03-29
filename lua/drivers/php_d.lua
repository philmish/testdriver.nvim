local phpunit_ext_driver = require("drivers.phpunit_ext_driver")

-- Test Driver for PHPUnit
---@class PhpunitDriver
---@field start_notification string Notification when command tests are run
---@field _cmd string Command to call to start phpunit
local phpunit_driver = {
    start_notification = "Starting PHPUnit tests ...",
    _cmd = "./vendor/bin/phpunit",
    _cache = {
        output = {}
    },
}

phpunit_driver.stdout = function (data)
    if not data then
        return
    end

    for _, line in ipairs(data) do
        if line ~= "" then
            table.insert(phpunit_driver._cache.output, line)
        end
    end
end

phpunit_driver.exit = function ()
    if #phpunit_driver._cache.output == 0 then
        vim.notify("No PHP test output", vim.log.levels.WARN, {
            title = "Test Driver PHP Unit",
            timeout = 1000,
        })
    else
        vim.notify(
            phpunit_driver._cache.output[#phpunit_driver._cache.output],
            vim.log.levels.INFO, {
                title = "Test Driver PHP Unit",
                timeout = 2000,
            }
        )
    end
end

phpunit_driver._run_test = function (bufnr, ns)
    vim.notify(
        phpunit_driver.start_notification,
        vim.log.levels.INFO, {
                title = "Test Driver",
                timeout = 1000
            }
        )
    vim.fn.jobstart(phpunit_driver._cmd, {
        stdout_buffered = true,
        on_stdout = function (_, data)
            phpunit_driver.stdout(data)
        end,
        on_exit = function ()
            phpunit_driver.exit()
        end
    })
end

local M = {
    runners = {
        ["phpunit"] = phpunit_driver,
        ["phpunitext"] = phpunit_ext_driver,
        ["default"] = phpunit_ext_driver,
    },
    loaded_runner = "default"
}

M.setup  = function (opts)
    local args = opts or {}
    vim.tbl_deep_extend("force", M, args)
end

M.load_runner = function (runner)
   M.loaded_runner = runner or "default"
end

M.run_test = function (runner)
    M.load_runner(runner)
    local loaded = M.runners[M.loaded_runner]
    if not loaded then
        vim.notify(
            {"Invalid test runner for PHP ", M.loaded_runner},
            vim.log.levels.ERROR
        )
        return
    end
    loaded._run_test()
end

M.get_output = function (runner)
    M.load_runner(runner)
    local loaded = M.runners[M.loaded_runner]
    if not loaded then
        vim.notify(
            {"Invalid test runner for PHP ", M.loaded_runner},
            vim.log.levels.ERROR
        )
        return
    end
    return loaded._cache.output
end

M.attach = function (bufnr, namespace, group, test_runner)
    M.load_runner(test_runner)
    local runner = M.runners[M.loaded_runner]
    if not runner then
        vim.notify(
            "Invalid test runner for PHP " .. M.loaded_runner,
            vim.log.levels.ERROR
        )
        return
    end

    vim.api.nvim_buf_create_user_command(bufnr, "RunTests", function ()
        runner._run_test(bufnr, namespace)
    end, {})

    if runner._load_diagnostics ~= nil then
        vim.api.nvim_buf_create_user_command(bufnr, "ShowDiag", function ()
            runner._load_diagnostics(namespace, bufnr)
        end, {})
    end
end

return M
