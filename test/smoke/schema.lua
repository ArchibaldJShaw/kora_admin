-- Admin schema is declared for kora_sql and applied through ensureTables.
local captured, threads = nil, {}
local calls, ensureResult = {}, { {}, nil }
local function spy(level)
    return function(event, message, fields) calls[#calls + 1] = { level = level, event = event, message = message, fields = fields } end
end
_G.Kora = { logging = { info = spy('info'), warn = spy('warn'), error = spy('error') }, sql = {
    NULL = {},
    ready = function() return true end,
    ensureTables = function(specs) captured = specs; return ensureResult[1], ensureResult[2] end,
} }
_G.CreateThread = function(fn) threads[#threads + 1] = fn end

dofile('server/schema.lua')
dofile('server/migrate.lua')
for _, fn in ipairs(threads) do fn() end

local names = {}
for _, spec in ipairs(KoraAdminSchema) do names[#names + 1] = spec.name end
local got = table.concat(names, ',')
assert(got == 'admin_logs,admin_reports,admin_report_messages', 'schema tables: ' .. got)
assert(captured == KoraAdminSchema, 'migrate must pass KoraAdminSchema to ensureTables')
assert(KoraAdminSchema[3].foreign[1].ref_table == 'admin_reports', 'messages FK must reference reports')
assert(#calls == 1 and calls[1].level == 'info' and calls[1].event == 'schema.up_to_date', 'success path logs schema.up_to_date')

-- Migrated error path: a failed ensureTables must emit error/schema.setup_failed carrying the error.
calls, ensureResult, threads = {}, { nil, 'boom' }, {}
dofile('server/migrate.lua')
for _, fn in ipairs(threads) do fn() end
assert(#calls == 1, 'one logger call expected, got ' .. #calls)
assert(calls[1].level == 'error' and calls[1].event == 'schema.setup_failed', 'error level/event')
assert(calls[1].fields.error == 'boom', 'fields carry the error')

-- Table warnings are warn level with the table name in fields.
calls, ensureResult, threads = {}, { { { table = 'admin_logs', warnings = { 'drift' } } }, nil }, {}
dofile('server/migrate.lua')
for _, fn in ipairs(threads) do fn() end
assert(calls[1].level == 'warn' and calls[1].event == 'schema.table_warning' and calls[1].fields.table == 'admin_logs', 'warning call')
print('schema: 6 passed')
