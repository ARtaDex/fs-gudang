-- Opsi 1: Jika tabel sudah ada, jalankan ini:
ALTER TABLE `gudang` ADD COLUMN `expired_at` DATETIME DEFAULT NULL;

-- Opsi 2: Jika buat baru:
CREATE TABLE IF NOT EXISTS `gudang` (
  `kode` varchar(10) DEFAULT NULL,
  `lokasi` varchar(50) DEFAULT NULL,
  `owner` varchar(60) DEFAULT NULL,
  `pin` varchar(10) DEFAULT NULL,
  `expired_at` DATETIME DEFAULT NULL, -- NULL artinya Permanen
  INDEX `idx_gudang_lokasi` (`lokasi`),
  INDEX `idx_gudang_owner` (`owner`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;