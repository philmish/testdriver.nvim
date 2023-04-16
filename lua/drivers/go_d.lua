local go_test = {
    start_notification = "Starting Go Tests",
    _cmd = "go test ./... -v -json",
    _cache = {
        passed = {},
        failed = {},
    }
}

go_test.set_cmd = function (cmd)
    go_test._cmd = cmd
end

go_test.reset_cache = function ()
    go_test._cache = {
        passed = {},
        failed = {},
    }
end

go_test.passed_packages = function ()
   local res = {}
   for k, _ in pairs(go_test._cache.passed) do
       table.insert(res, k .. " [✓]")
   end
   return res
end

go_test.failed_packages = function ()
    local res = {}
    for k, _ in pairs(go_test._cache.failed) do
        table.insert(res, k .. " [X]")
    end
    return res
end

go_test.stdout = function (data)
    if not data then
        return
    end

    for _, line in ipairs(data) do
        pcall(function ()
            local decoded = vim.json.decode(line)
            if decoded.Action == "pass" then
                if not go_test._cache.passed[decoded.Package] then
                    go_test._cache.passed[decoded.Package] = {
                        fun = {},
                        passed = true,
                    }
                    end
                if decoded.Test then
                    table.insert(
                        go_test._cache.passed[decoded.Package].fun,
                        decoded.Test
                    )
                end
            end
        end)
    end
end

go_test.exit = function ()
    local passed = go_test.passed_packages()
    local failed = go_test.failed_packages()
    if #passed == 0 and #failed == 0 then
        vim.notify("No go test results found", vim.log.levels.WARN, {
            title = "Test Driver Go"
        })
        return
    end
    if #passed > 0 or #failed > 0 then
        vim.notify(passed, vim.log.levels.INFO, {
            title = "Test Driver Passed",
            timeout = 1000,
            on_close = function ()
                if #failed > 0 then
                    vim.notify(failed,  vim.log.levels.WARN, {
                        title = "Test Driver Failed",
                        timeout = 2000,
                    })
                end
            end
        })
    end
end

go_test._run_test = function ()
    vim.notify = require("notify")
    vim.notify(go_test.start_notification, vim.log.levels.INFO, {
        title = "Test Driver",
    })

    vim.fn.jobstart(go_test._cmd, {
        stdout_buffered = true,
        on_stdout = function (_, data)
            go_test.stdout(data)
        end,
        on_exit = function ()
            go_test.exit()
        end
    })
end

local M = {
    runners = {
        ["go_test"] = go_test,
        ["default"] = go_test,
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
            {"Invalid test runner for Go ", M.loaded_runner},
            vim.log.levels.ERROR
        )
        return
    end
    loaded._run_test()
end

return M
