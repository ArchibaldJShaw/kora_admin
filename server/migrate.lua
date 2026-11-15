-- Declares kora_admin's tables at boot through kora_sql's schema handler.

CreateThread(function()
    local ok = Kora.sql.ready(60000)
    if not ok then
        Kora.logging.error('schema.sql_not_ready', 'kora_sql never became ready; admin logs and reports unavailable')
        return
    end

    local reports, err = Kora.sql.ensureTables(KoraAdminSchema)
    if err then
        Kora.logging.error('schema.setup_failed', 'Schema setup failed', { error = tostring(err) })
        return
    end
    for _, report in ipairs(reports or {}) do
        for _, warning in ipairs(report.warnings or {}) do
            Kora.logging.warn('schema.table_warning', 'Schema reported a table warning', {
                table = tostring(report.table), warning = tostring(warning),
            })
        end
    end
    Kora.logging.info('schema.up_to_date', 'Schema up to date')
end)
