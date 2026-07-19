CREATE TABLE IF NOT EXISTS `civix_electrician_progress` (
  `citizenid` varchar(64) NOT NULL,
  `xp` int NOT NULL DEFAULT 0,
  `level` int NOT NULL DEFAULT 1,
  `repairs` int NOT NULL DEFAULT 0,
  `failed_repairs` int NOT NULL DEFAULT 0,
  `earnings` int NOT NULL DEFAULT 0,
  `best_score` int NOT NULL DEFAULT 0,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;