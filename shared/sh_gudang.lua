Config = {}

-- Harga
Config.PriceRent = 50000   -- Harga Sewa 7 Hari
Config.PricePerm = 2000000  -- Harga Beli Permanen
Config.RefundPercent = 0.5 -- Dapat uang kembali 50% saat hapus gudang

Config.MaxSlots = 150         -- Jumlah Slot
Config.MaxWeight = 1500000    -- Berat dalam GRAM (1000000 = 1000 KG)

-- Durasi Sewa (dalam hari)
Config.RentDuration = 7

-- Lokasi Gudang (Sama seperti sebelumnya)
Config.Locations = {
    ["kota"] = {
        label = "Gudang Kota",
        hash = "gudang_kota",
        coords = vec3(-1607.4850, -830.1636, 10.0785),
        blip = true -- Set true untuk muncul di map
    },
    ["ss"] = {
        label = "Gudang Sandy Shores",
        hash = "gudang_ss",
        coords = vec3(1731.6257, 3707.5032, 34.1122),
        blip = true
    },
    ["paleto"] = {
        label = "Gudang Paleto",
        hash = "gudang_paleto",
        coords = vec3(146.9039, 6366.7075, 31.5292),
        blip = true
    },
}