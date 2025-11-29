local ESX = exports['es_extended']:getSharedObject()

local function AccessGudangByPin(lokasi)
    local input = lib.inputDialog('Akses Gudang', {
        { type = 'input', label = 'Kode Gudang', placeholder = 'ABCD12', required = true },
        { type = 'input', label = 'PIN', password = true, required = true, icon = 'lock' },
    })
    if not input then return end
    local kode = input[1]:upper()
    local pin = input[2]

    local data = lib.callback.await('gudang:loginPin', false, {
        lokasi = lokasi,
        kode = kode,
        pin = pin
    })

    if data then
        local stashId = data.lokasi .. '_' .. data.kode
        exports.ox_inventory:openInventory('stash', stashId)
    else
        lib.notify({type = 'error', description = 'Kode atau PIN salah!'})
    end
end

local function BuyGudang(hashLocation)
    -- Input Dialog dengan Pilihan Tipe Sewa
    local input = lib.inputDialog('Beli / Sewa Gudang', {
        { 
            type = 'select', 
            label = 'Tipe Pembelian', 
            options = {
                { value = 'rent', label = 'Sewa '..Config.RentDuration..' Hari ($'..Config.PriceRent..')' },
                { value = 'perm', label = 'Beli Permanen ($'..Config.PricePerm..')' }
            },
            required = true
        },
        { type = 'input', label = 'Buat PIN', password = true, required = true, icon = 'lock' },
    })

    if not input then return end

    TriggerServerEvent('gudang:buyGudang', {
        location = hashLocation,
        type = input[1],
        pin = input[2]
    })
end

local function SellGudang(ownedData)
    local alert = lib.alertDialog({
        header = 'Hapus Gudang?',
        content = 'Apakah anda yakin ingin menghapus/menjual gudang ini? Item didalamnya akan hilang aksesnya.',
        centered = true,
        cancel = true
    })

    if alert == 'confirm' then
        TriggerServerEvent('gudang:sellGudang', {
            kode = ownedData.kode,
            lokasi = ownedData.lokasi
        })
    end
end

local function ChangePin(ownedData)
    local input = lib.inputDialog('Ubah PIN Gudang '..ownedData.kode, {
        { type = 'input', label = 'PIN Baru', password = true, required = true },
    })
    if not input then return end
    local success = lib.callback.await('gudang:updatePin', false, {
        kode = ownedData.kode,
        pin = input[1]
    })
    if success then
        lib.notify({type = 'success', description = 'PIN berhasil diubah'})
    else
        lib.notify({type = 'error', description = 'Gagal mengubah PIN'})
    end
end

local function OpenGudangMenu(locationHash)
    local ownedData = lib.callback.await('gudang:checkOwned', false, locationHash)
    local options = {}

    -- Opsi 1: Masuk pakai PIN
    table.insert(options, {
        title = 'Akses dengan Kode & PIN',
        description = 'Masuk ke gudang orang lain atau gudangmu',
        icon = 'unlock-keyhole',
        onSelect = function() AccessGudangByPin(locationHash) end
    })

    -- Opsi 2: Menu Pemilik
    if ownedData then
        -- Format Status Expired
        local statusText = "Permanen"
        if ownedData.expired_at then
            -- Konversi timestamp ke tanggal terbaca
            statusText = "Sewa Habis: " .. os.date('%d/%m/%Y', ownedData.expired_at)
        end

        table.insert(options, {
            title = 'Buka Gudang Saya',
            description = 'Kode: ' .. ownedData.kode .. ' | ' .. statusText,
            icon = 'box-open',
            onSelect = function()
                local stashId = ownedData.lokasi .. '_' .. ownedData.kode
                exports.ox_inventory:openInventory('stash', stashId)
            end
        })

        table.insert(options, {
            title = 'Ganti PIN',
            icon = 'user-lock',
            onSelect = function() ChangePin(ownedData) end
        })

        table.insert(options, {
            title = 'Jual / Hapus Gudang',
            description = 'Kembalikan gudang (Refund '..(Config.RefundPercent*100)..'%)',
            icon = 'trash-can',
            iconColor = 'red',
            onSelect = function() SellGudang(ownedData) end
        })
    else
        -- Opsi 3: Beli (Jika belum punya)
        table.insert(options, {
            title = 'Beli / Sewa Gudang',
            description = 'Mulai dari $' .. Config.PriceRent,
            icon = 'money-bill',
            onSelect = function() BuyGudang(locationHash) end
        })
    end

    lib.registerContext({
        id = 'gudang_main_menu',
        title = 'Menu Gudang',
        options = options
    })
    lib.showContext('gudang_main_menu')
end

Citizen.CreateThread(function()
    for k, v in pairs(Config.Locations) do
        
        -- LOGIKA BLIP (Hanya buat blip jika config v.blip bernilai true)
        if v.blip then
            local blip = AddBlipForCoord(v.coords)
            SetBlipSprite(blip, 473)
            SetBlipDisplay(blip, 4)
            SetBlipScale(blip, 0.7)
            SetBlipColour(blip, 25)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(v.label)
            EndTextCommandSetBlipName(blip)
        end

        -- LOGIKA TARGET/INTERAKSI (Tetap dibuat meskipun blip dimatikan)
        exports.ox_target:addSphereZone({
            coords = v.coords,
            radius = 1.5,
            debug = false,
            options = {
                {
                    name = 'gudang_'..k,
                    icon = 'fa-solid fa-warehouse',
                    label = 'Akses ' .. v.label,
                    onSelect = function()
                        OpenGudangMenu(v.hash)
                    end
                }
            }
        })
    end
end)