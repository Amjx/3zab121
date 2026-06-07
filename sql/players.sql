-- Tabela necessaria para um-ronin-multicharacter funcionar com ESX.
-- Execute este arquivo no banco de dados da sua ESX (ex: esx_clearbyrafa).

CREATE TABLE IF NOT EXISTS `players` (
  `id`         INT          NOT NULL AUTO_INCREMENT,
  `license`    VARCHAR(50)  NOT NULL,
  `license2`   VARCHAR(100) DEFAULT NULL,
  `citizenid`  VARCHAR(50)  NOT NULL,
  `cid`        INT          NOT NULL DEFAULT 1,
  `name`       VARCHAR(255) NOT NULL DEFAULT '',
  `money`      LONGTEXT     DEFAULT NULL,
  `charinfo`   LONGTEXT     DEFAULT NULL,
  `job`        LONGTEXT     DEFAULT NULL,
  `gang`       LONGTEXT     DEFAULT NULL,
  `position`   LONGTEXT     DEFAULT NULL,
  `metadata`   LONGTEXT     DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `citizenid` (`citizenid`),
  KEY `license_idx` (`license`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
