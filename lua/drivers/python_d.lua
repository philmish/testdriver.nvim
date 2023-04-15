local unittest_driver = {
    _cache = {
        output = {},
        coverage = {},
    },
    _cmd = "python3 -m unittest",
    _with_coverage = "coverage run -m unittest && coverage json && cat coverage.json",
    start_notification = "Starting python tests ...",
}

unittest_driver.set_cmd = function (cmd)
    unittest_driver._cmd = cmd
end

unittest_driver.clear_cache = function ()
    unittest_driver._cache = {
        output = {},
        coverage = {},
    }
end

unittest_driver.stderr = function (data)
    if not data then
        return
    end

    for _, line in ipairs(data) do
        if line ~= "" then
            table.insert(unittest_driver._cache.output, line)
        end
    end
end

unittest_driver.stdout = function(data)
    if not data then
        return
    end
    local out = {}
    for _, line in ipairs(data) do
        if line ~= "" then
            table.insert(out, line)
        end
    end

    pcall(function ()
        unittest_driver._cache.coverage = vim.json.decode(out[#out])
    end)
end

unittest_driver.exit = function (coverage)
    if #unittest_driver._cache.output == 0 then
        vim.notify("No python test output", vim.log.levels.WARN, {
            title = "Test Driver Python",
            timeout = 1000,
        })
    else
        vim.notify(unittest_driver._cache.output[#unittest_driver._cache.output], vim.log.levels.INFO, {
            title = "Test Driver Python",
            timeout = 2000,
            on_close = function ()
                if coverage then
                    vim.notify(
                    "Coverage: " .. unittest_driver._cache.coverage.totals.percent_covered_display .. "%",
                    vim.log.levels.INFO, {
                        title = "Test Driver Coverage"
                    })
                end
            end
        })
    end
end

unittest_driver._run_test = function ()
    vim.notify = require("notify")
    vim.notify(unittest_driver.start_notification, vim.log.levels.INFO, {
        title = "Test Driver",
        timeout = 1000,
    })

    vim.fn.jobstart(unittest_driver._cmd, {
        stdout_buffered = true,
        on_stderr = function (_, data)
            unittest_driver.stderr(data)
        end,
        on_exit = function ()
            unittest_driver.exit(false)
        end
    })
end

unittest_driver._run_with_coverage = function ()
    vim.notify = require("notify")
    vim.notify(unittest_driver.start_notification, vim.log.levels.INFO, {
        title = "Test Driver with Coverage",
        timeout = 1000,
    })

    vim.fn.jobstart(unittest_driver._with_coverage, {
        stdout_buffered = true,
        on_stdout = function (_, data)
            unittest_driver.stdout(data)
        end,
        on_stderr = function (_, data)
            unittest_driver.stderr(data)
        end,
        on_exit = function ()
            unittest_driver.exit(true)
        end
    })
end

local M = {
    runners = {
        ["unittest"] = unittest_driver,
        ["default"] = unittest_driver,
    },
    loaded_runner = "default"
}

M.setup  = function (opts)
    local args = opts or {}
    vim.tbl_deep_extend("force", args)
end

M.load_runner = function (runner)
   M.loaded_runner = runner or "default"
end

M.run_test = function (runner)
    M.load_runner(runner)
    local loaded = M.runners[M.loaded_runner]
    if not loaded then
        vim.notify(
            {"Invalid test runner for Python ", M.loaded_runner},
            vim.log.levels.ERROR
        )
        return
    end
    loaded._run_test()
end

M.with_coverage = function (runner)
    M.load_runner(runner)
    local loaded = M.runners[M.loaded_runner]
    if not loaded then
        vim.notify(
            {"Invalid test runner for Python ", M.loaded_runner},
            vim.log.levels.ERROR
        )
        return
    end
    loaded._run_with_coverage()
end

return M
