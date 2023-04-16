local jest_driver = {
    _cmd = "npm test 2>&1 | tail -1",
    _cache = {
        passed_suites = 0,
        passed_tests = 0,
        failed_suites = 0,
        failed_tests = 0,
        total_suites = 0,
        total_tests = 0,
        results = {},
    }
}

jest_driver.passed_suite_ratio = function ()
    return "[" .. jest_driver._cache.passed_suites .. "/" .. jest_driver._cache.total_suites .. "]"
end

local passed_tests_ratio = function ()
    return "[" .. jest_driver._cache.passed_tests .. "/" .. jest_driver._cache.total_tests .. "]"
end

local failed_suite_ratio = function ()
    return "[" .. jest_driver._cache.failed_suites .. "/" .. jest_driver._cache.total_suites .. "]"
end

local failed_tests_ratio = function ()
    return "[" .. jest_driver._cache.failed_tests .. "/" .. jest_driver._cache.total_tests .. "]"
end

jest_driver.get_failing_test_files = function ()
    local failing = {}
    for _, result in pairs(jest_driver._cache.results) do
        if result.name then
            table.insert(failing, result.name)
        end
    end
    return failing
end

jest_driver.exit = function ()
    local smsg = {
        "Passed Suites: " .. jest_driver.passed_suite_ratio(),
        "Passed tests: " .. passed_tests_ratio()
    }
    vim.notify(smsg, vim.log.INFO, {
        title = "Test Driver Jest",
        timeout = 2000,
        on_close = function ()
            if jest_driver._cache.failed_suites > 0 then
                local failing = jest_driver.get_failing_test_files()
                local fmsg = {
                    "Failed Suites: " .. failed_suite_ratio(),
                    "Failed tests: " .. failed_tests_ratio(),
                }
                for _, i in pairs(failing) do
                    table.insert(fmsg, i)
                end
                vim.notify(fmsg, vim.log.levels.WARN, {
                    title = "Test Driver Jest",
                })
            end
        end
    })

end

jest_driver._run_test = function ()
    vim.notify = require("notify")
    vim.notify("Starting jest tests ...", vim.log.levels.INFO, {
        title = "Test Driver",
        timeout = 1000,
    })

    vim.fn.jobstart(jest_driver._cmd, {
        stdout_buffered = true,
        on_stdout = function (_, data)
           if not data then
                return
           end

           for _, line in ipairs(data) do
                pcall(function ()
                    local decoded = vim.json.decode(line)

                    if decoded.numFailedTestSuites then
                        jest_driver._cache.failed_suites = decoded.numFailedTestSuites
                    end
                    if decoded.numPassedTestSuites then
                        jest_driver._cache.passed_suites = decoded.numPassedTestSuites
                    end
                    if decoded.numFailedTests then
                        jest_driver._cache.failed_tests = decoded.numFailedTests
                    end
                    if decoded.numPassedTests then
                        jest_driver._cache.passed_tests = decoded.numPassedTests
                    end
                    if decoded.numTotalTestSuites then
                        jest_driver._cache.total_suites = decoded.numTotalTestSuites
                    end
                    if decoded.numTotalTests then
                        jest_driver._cache.total_tests = decoded.numTotalTests
                    end
                    if decoded.testResults then
                        jest_driver._cache.results = decoded.testResults
                    end
                end)
           end

        end,
        on_exit = function ()
            jest_driver.exit()
        end
    })
end

local M = {
    runners = {
        ["jest"] = jest_driver,
        ["default"] = jest_driver,
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
            {"Invalid test runner for JS ", M.loaded_runner},
            vim.log.levels.ERROR
        )
        return
    end
    loaded._run_test()
end

return M
