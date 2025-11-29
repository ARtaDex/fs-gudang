local ESX = exports['es_extended']:getSharedObject()
local ListGudang = {}

-- Fungsi untuk membersihkan gudang yang sudah expired
local function CheckExpiredGudang()
    -- Hapus gudang yang expired_at nya < NOW()
    local affected = MySQL.update.await('DELETE FROM gudang WHERE expired_at IS NOT NULL AND expired_at < NOW()')
    if affected > 0 then
        print('^3[Gudang]^7 Menghapus ' .. affected .. ' gudang yang masa sewanya habis.')
    end
end

-- Load Data saat start
local function LoadAllGudang()
    CheckExpiredGudang() -- Bersihkan dulu yang expired sebelum load
    ListGudang = {}
    local result = MySQL.query.await('SELECT *, UNIX_TIMESTAMP(expired_at) as expired_ts FROM gudang')

    if result then
        for i = 1, #result do
            local data = result[i]
            if not ListGudang[data.lokasi] then ListGudang[data.lokasi] = {} end
            
            ListGudang[data.lokasi][data.kode] = {
                kode = data.kode,
                lokasi = data.lokasi,
                owner = data.owner,
                pin = data.pin,
                expired_at = data.expired_ts -- Simpan timestamp untuk dikirim ke client
            }

            -- Register Stash ke ox_inventory
            local stashId = data.lokasi .. '_' .. data.kode
            local label = "Gudang " .. data.kode
            exports.ox_inventory:RegisterStash(stashId, label, Config.MaxSlots, Config.MaxWeight, data.owner)
        end
    end
    print("^2[Gudang]^7 Data Loaded.")
end

-- Generator Kode Unik
local function GenerateKode()
    local charset = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local res = ""
    for i = 1, 6 do
        local rand = math.random(#charset)
        res = res .. string.sub(charset, rand, rand)
    end
    return res
end

-- Event Beli Gudang (Sewa / Permanen)
RegisterNetEvent('gudang:buyGudang', function(data)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    local pin = data.pin
    local lokasi = data.location
    local tipe = data.type -- 'rent' atau 'perm'
    local identifier = xPlayer.identifier
    
    local price = (tipe == 'perm') and Config.PricePerm or Config.PriceRent
    
    -- Cek Uang
    if xPlayer.getMoney() < price then
        return TriggerClientEvent('ox_lib:notify', src, {type = 'error', description = 'Uang tidak cukup!'})
    end

    -- Generate Kode
    local kode = GenerateKode()
    local check = MySQL.scalar.await('SELECT count(*) FROM gudang WHERE kode = ?', {kode})
    if check > 0 then kode = GenerateKode() end

    -- Tentukan Query berdasarkan tipe
    local query = ''
    local params = {}
    
    if tipe == 'perm' then
        query = 'INSERT INTO gudang (kode, lokasi, owner, pin, expired_at) VALUES (?, ?, ?, ?, NULL)'
        params = {kode, lokasi, identifier, pin}
    else
        -- Tambah 7 hari dari sekarang
        query = 'INSERT INTO gudang (kode, lokasi, owner, pin, expired_at) VALUES (?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL ? DAY))'
        params = {kode, lokasi, identifier, pin, Config.RentDuration}
    end

    MySQL.insert(query, params, function(id)
        if id then
            xPlayer.removeMoney(price)
            
            -- Ambil data expired barusan untuk cache
            local expiredData = nil
            if tipe == 'rent' then
                expiredData = os.time() + (Config.RentDuration * 24 * 60 * 60)
            end

            -- Update Cache Server
            if not ListGudang[lokasi] then ListGudang[lokasi] = {} end
            ListGudang[lokasi][kode] = {
                kode = kode,
                lokasi = lokasi,
                owner = identifier,
                pin = pin,
                expired_at = expiredData
            }

            -- Register Stash
            local stashId = lokasi .. '_' .. kode
            local label = "Gudang " .. kode
            exports.ox_inventory:RegisterStash(stashId, label, Config.MaxSlots, Config.MaxWeight, identifier)

            TriggerClientEvent('ox_lib:notify', src, {type = 'success', description = 'Berhasil! Kode: '..kode})
        else
            TriggerClientEvent('ox_lib:notify', src, {type = 'error', description = 'Database error'})
        end
    end)
end)

-- Event Hapus/Jual Gudang
RegisterNetEvent('gudang:sellGudang', function(data)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    local kode = data.kode
    local lokasi = data.lokasi

    -- Validasi Owner Server Side
    if ListGudang[lokasi] and ListGudang[lokasi][kode] then
        local gd = ListGudang[lokasi][kode]
        if gd.owner == xPlayer.identifier then
            
            MySQL.update.await('DELETE FROM gudang WHERE kode = ?', {kode})
            
            -- Hapus dari cache
            ListGudang[lokasi][kode] = nil
            
            -- Refund Uang (Hitung refund dari harga sewa atau permanen)
            local refundAmount = 0
            if gd.expired_at then -- Jika sewa
                refundAmount = math.floor(Config.PriceRent * Config.RefundPercent)
            else -- Jika permanen
                refundAmount = math.floor(Config.PricePerm * Config.RefundPercent)
            end
            
            xPlayer.addMoney(refundAmount)
            TriggerClientEvent('ox_lib:notify', src, {type = 'success', description = 'Gudang dijual seharga $'..refundAmount})
        else
            TriggerClientEvent('ox_lib:notify', src, {type = 'error', description = 'Bukan milikmu!'})
        end
    end
end)

lib.callback.register('gudang:checkOwned', function(source, location)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return nil end
    local identifier = xPlayer.identifier
    
    if ListGudang[location] then
        for kode, data in pairs(ListGudang[location]) do
            if data.owner == identifier then
                return data
            end
        end
    end
    return nil
end)

lib.callback.register('gudang:loginPin', function(source, data)
    local lokasi = data.lokasi
    local kode = data.kode
    local pin = data.pin
    if ListGudang[lokasi] and ListGudang[lokasi][kode] then
        if ListGudang[lokasi][kode].pin == pin then
            return ListGudang[lokasi][kode]
        end
    end
    return nil
end)

lib.callback.register('gudang:updatePin', function(source, data)
    local xPlayer = ESX.GetPlayerFromId(source)
    local kode = data.kode
    local pin = data.pin
    
    local currentData = nil
    for loc, list in pairs(ListGudang) do
        if list[kode] then currentData = list[kode] break end
    end

    if currentData and currentData.owner == xPlayer.identifier then
        MySQL.update.await('UPDATE gudang SET pin = ? WHERE kode = ?', {pin, kode})
        ListGudang[currentData.lokasi][kode].pin = pin
        return true
    end
    return false
end)

AddEventHandler('onResourceStart', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then return end
    LoadAllGudang()
end)