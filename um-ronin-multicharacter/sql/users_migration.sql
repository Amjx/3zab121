-- ============================================================
-- Migracion para soporte multicharacter en tabla users de ESX
-- Ejecutar en la base de datos de tu servidor ESX
-- Es seguro volver a ejecutar (usa IF NOT EXISTS / WHERE guards)
-- ============================================================

-- Agrega columnas necesarias para multichar
ALTER TABLE `users`
    ADD COLUMN IF NOT EXISTS `license`  VARCHAR(60)  DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS `license2` VARCHAR(100) DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS `cid`      INT          DEFAULT NULL;

-- ============================================================
-- PASO 1: Para filas con formato antiguo (identifier = "license:hex" sin charN:)
-- - Guarda el identifier original en la columna license
-- - Asigna cid = 1
-- - Convierte identifier al formato ESX multichar: char1:hex
-- ============================================================

-- 1a. Copiar identifier a license (para filas sin charN: prefix)
UPDATE `users`
SET `license` = `identifier`,
    `cid`     = 1
WHERE `identifier` NOT LIKE 'char%:%'
  AND `license` IS NULL;

-- 1b. Convertir identifier al formato charN:hex (quitar prefijo "license:")
UPDATE `users`
SET `identifier` = CONCAT('char', COALESCE(`cid`, 1), ':', REPLACE(`identifier`, 'license:', ''))
WHERE `identifier` NOT LIKE 'char%:%'
  AND `license` IS NOT NULL;

-- ============================================================
-- PASO 2: Para filas ESX multichar (identifier = "charN:hex")
-- donde license o cid esten en NULL (ej. recien creadas por ESX)
-- - Reconstruir license desde identifier
-- ============================================================
UPDATE `users`
SET
    `cid`     = CAST(SUBSTRING(`identifier`, 5, LOCATE(':', `identifier`, 5) - 5) AS UNSIGNED),
    `license` = CONCAT('license:', SUBSTRING(`identifier`, LOCATE(':', `identifier`) + 1))
WHERE `identifier` LIKE 'char%:%'
  AND (`cid` IS NULL OR `license` IS NULL);

-- Indice para busquedas rapidas por license
CREATE INDEX IF NOT EXISTS `idx_users_license` ON `users` (`license`);

