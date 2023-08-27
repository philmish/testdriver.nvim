local ts_query_method = [[
(method_declaration
    (name) @testname (#eq? "%s")    
)
]]

---Returns the line num for a test method
---@param name string
local function get_test_line(name, bufnr)
    local formatted = string.format(ts_query_method, name)
    local query = vim.treesitter.query.parse("php", formatted)
    local parser = vim.treesitter.get_parser(bufnr, "php", {})
    local tree = parser:parse()[1]
    local root = tree:root()

    for id, node in query:iter_captures(root, bufnr, 0, -1) do
        if id == 1 then
            local range = { node:range() }
            return range[1]
        end
    end
end

--- Cache for Testdriver for the testdriver phpunit extension
---@class PhpunitExtDriverCache
local PhpunitExtDriverCache = {
    test_map = {},
    num_passed = 0,
    num_failed = 0
}

---@param file string Absolute Path to file which contains the test
---@param class string  Name of the class which contains the test
---@param name string  Name of the test method
---@param line integer Line in which the test method starts
function PhpunitExtDriverCache.add_passed_test(file, class, name, line)
    if not PhpunitExtDriverCache.test_map[file] then
        PhpunitExtDriverCache.test_map[file]= {}
    end
    if not PhpunitExtDriverCache.test_map[file][class] then
        PhpunitExtDriverCache.test_map[file][class] = {}
    end

    PhpunitExtDriverCache.test_map[file][class][name] = {
        passed = true,
        line = line
    }
    PhpunitExtDriverCache.num_passed = PhpunitExtDriverCache.num_passed + 1
end

---@param file string Absolute Path to file which contains the test
---@param class string  Name of the class which contains the test
---@param name string  Name of the test method
---@param line integer Line in which the test method starts
function PhpunitExtDriverCache.add_failed_test(file, class, name, line)
    if not PhpunitExtDriverCache.test_map[file] then
        PhpunitExtDriverCache.test_map[file]= {}
    end
    if not PhpunitExtDriverCache.test_map[file][class] then
        PhpunitExtDriverCache.test_map[file][class] = {}
    end

    PhpunitExtDriverCache.test_map[file][class][name] = {
        passed = false,
        line = line
    }
    PhpunitExtDriverCache.num_failed = PhpunitExtDriverCache.num_failed + 1
end

---@return integer
function PhpunitExtDriverCache.num_tests_run()
    return PhpunitExtDriverCache.num_failed + PhpunitExtDriverCache.num_passed
end

---@return boolean
function PhpunitExtDriverCache.all_tests_passed()
    local tests_ran = PhpunitExtDriverCache.num_tests_run()
    return tests_ran > 0 and PhpunitExtDriverCache.num_passed == tests_ran
end

---@return string
function PhpunitExtDriverCache.render_passed_ratio()
   return string.format("[%d/%d]", PhpunitExtDriverCache.num_passed, PhpunitExtDriverCache.num_tests_run())
end

---@return boolean
function PhpunitExtDriverCache.is_empty()
    return #PhpunitExtDriverCache.test_map == 0
end

function PhpunitExtDriverCache.clear()
    PhpunitExtDriverCache.test_map = {}
    PhpunitExtDriverCache.num_passed = 0
    PhpunitExtDriverCache.num_failed = 0
end

--- Driver to use with the testdriver phpunit extension
---@class PhpunitExtDriver
---@field start_notification string Notification when command tests are run
---@field _cmd string Command to call to start phpunit
local phpunit_ext_driver = {
    start_notification = "Starting PHPUnit tests with testdriver extension ...",
    _cmd = "./vendor/bin/phpunit --no-output",
    _test_data = PhpunitExtDriverCache
}

--- Number of cached test results
---@return integer
phpunit_ext_driver.num_tests_run = function ()
   return phpunit_ext_driver._test_data.num_tests_run()
end

--- All tests which ran passed
---@return boolean
phpunit_ext_driver.all_passed = function ()
    return phpunit_ext_driver._test_data.all_tests_passed()
end

---@return boolean
phpunit_ext_driver.has_mapped_tests = function ()
    return next(phpunit_ext_driver._test_data.test_map) == nil
end

function phpunit_ext_driver.append_test_result(decoded)
    local event = decoded.event

    if not decoded.file then
        return
    end
    local file = decoded.file

    if not decoded.class then
        return
    end
    local class = decoded.class

    if not decoded.name then
        return
    end
    local name = decoded.name
    if not decoded.line then
        return
    end
    local line = decoded.line

    if event == "test.failed" then
       phpunit_ext_driver._test_data.add_failed_test(file, class, name, line)
    end
    if event == "test.passed" then
        phpunit_ext_driver._test_data.add_passed_test(file, class, name, line)
    end
end

phpunit_ext_driver._run_test = function (bufnr, ns)
    vim.notify(
        phpunit_ext_driver.start_notification,
        vim.log.levels.INFO, {
                title = "Test Driver",
                timeout = 1000
            }
        )
    phpunit_ext_driver._test_data.clear()
    vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

    vim.fn.jobstart(phpunit_ext_driver._cmd, {
        stdout_buffered = true,
        on_stdout = function (_, data)
            if not data then
                return
            end
            for _, line in ipairs(data) do
                pcall(function ()
                    local decoded = vim.fn.json_decode(line)
                    if not decoded then
                        return
                    end

                    if decoded.event then
                        phpunit_ext_driver.append_test_result(decoded)
                    end
                end, {})
            end

        end,
        on_exit = function ()
            local ratio = phpunit_ext_driver._test_data.render_passed_ratio()
            if phpunit_ext_driver.all_passed() then
                vim.notify(ratio, vim.log.levels.INFO, {
                    title = "PHPUnit Testdriver"
                })
                return
            end
            vim.notify(ratio, vim.log.levels.WARN, {
                    title = "PHPUnit Testdriver"
            })
        end,
    })
end

function phpunit_ext_driver._load_diagnostics(ns, bufnr)
    local file = vim.fn.expand('%:p')
    if phpunit_ext_driver._test_data.test_map[file] ~= nil then
        local data = phpunit_ext_driver._test_data.test_map[file]
        local failed ={}
        vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
        for class, tests in pairs(data) do
            for name, info in pairs(tests) do
                local line = get_test_line(name, bufnr)
                if info.passed then
                    local text = { "Passed ✓" }
                    vim.api.nvim_buf_set_extmark(bufnr, ns, line, 0, {
                        virt_text = { text }
                    })
                else
                    table.insert(failed, {
                        bufnr = bufnr,
                        lnum = line,
                        col = 0,
                        severity = vim.diagnostic.severity.ERROR,
                        source = "phpunit-ext-testdriver",
                        message = "Test Failed",
                        user_data = {},
                    })
                end
            end
        end
        vim.diagnostic.set(ns, bufnr, failed, {})
    end
end

return phpunit_ext_driver
