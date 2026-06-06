local query = {
    -- Usa la tabla `users` de ESX.
    -- Requiere columnas license, license2 y cid (ver sql/users_migration.sql)
    getAllCharactersQuery = [[
        SELECT
            identifier AS citizenid,
            cid,
            JSON_OBJECT(
                'firstname',   COALESCE(firstname,   ''),
                'lastname',    COALESCE(lastname,    ''),
                'birthdate',   COALESCE(dateofbirth, ''),
                'gender',      COALESCE(sex,         ''),
                'nationality', ''
            ) AS charinfo,
            COALESCE(accounts, '{"cash":0,"bank":0}') AS money,
            JSON_OBJECT(
                'name',  COALESCE(job, 'unemployed'),
                'label', COALESCE(job, 'Unemployed'),
                'grade', JSON_OBJECT('name', '', 'level', COALESCE(job_grade, 0))
            ) AS job,
            position
        FROM users
        WHERE (license = ? OR license2 = ?) AND cid IS NOT NULL
        ORDER BY cid
    ]],
    getCharacterCountQuery = 'SELECT COUNT(*) FROM users WHERE (license = ? OR license2 = ?) AND cid IS NOT NULL',
    deleteCharacterQuery   = 'SELECT license FROM users WHERE identifier = ? LIMIT 1',
    tebexSlotsQuery        = 'SELECT COALESCE(SUM(slots_count), 0) FROM ronin_slots WHERE (license = ? OR license = ?) AND claim = 1'
}

return query
