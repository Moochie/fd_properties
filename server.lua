local OwnedProperties = {}
local AvailableProperties = {}
local ForSaleProperties = {}

RegisterServerEvent('fd_p:test')
AddEventHandler('fd_p:test', function()
	SyncProperties()
end)

RegisterServerEvent('FD_Properties:PurchaseHouse')
AddEventHandler('FD_Properties:PurchaseHouse', function(Key, paymentOption)
	local src = source
	local key = Key
	if paymentOption == 'Buy' then
		BuyHouse(src, key)
	elseif paymentOption == 'Mortgage' then
		MortgageHouse(src, key)
	end
end)

function SyncProperties()
	AvailableProperties = {}
	local Properties = exports['externalsql']:AsyncQuery({
		query = [[SELECT * FROM owned_properties]]
	})
	local Properties = Properties['data']
	--print('Owned: ', dump(Properties))
	local NewOwnedProperties = {}
	for k,v in pairs(Properties) do
		local PropertyOwned = false
		for k2, v2 in pairs(OwnedProperties) do
			if v.key == v2.key then
				PropertyOwned = true	
			end
		end
		NewOwnedProperties[v.key] = v
		NewOwnedProperties[v.key].keys = json.decode(Properties[k]['keys'])
		local stash = json.decode(Properties[k]['stash'])
		local x, y, z = stash.x, stash.y, stash.z
		print('Stash: ', x,y,z)
		NewOwnedProperties[v.key].stash = vector3(x,y,z)
		print(NewOwnedProperties[v.key].stash)
		if PropertyOwned then
			NewOwnedProperties[v.key].status = OwnedProperties[v.key].status
		end
	end
	OwnedProperties = NewOwnedProperties
	--print('Owned: ', dump(OwnedProperties))
	for k,v in pairs(Config.Properties) do
		local Available = true
		for k2,v2 in pairs(OwnedProperties) do
		 	if k == k2 then
		 		Available = false
		 	end
		end
		if Available then
			AvailableProperties[k] = v
		end
	end
	--print('Available: ', dump(AvailableProperties))
end

function BuyHouse(src, Key)
	local key = Key
	local payments = 0
	local amount = 0
	local cost = Config.Properties[key].Cost
	local CharacterData = exports["drp_id"]:GetCharacterData(src)
	TriggerEvent('DRP_Bank:GetCharacterMoney', CharacterData.charid, function(characterMoney)
		local bankBalance = characterMoney.data[1].bank
		if bankBalance >= cost then
			newBankBalance = bankBalance-cost
			--print('Take money')
			exports['externalsql']:AsyncQuery({
				query = 'UPDATE characters SET bank = :bank WHERE id = :charid',
				data = {
					bank = newBankBalance,
					charid = CharacterData.charid
				}
			})
			--print('Insert into properties')
			exports['externalsql']:AsyncQuery({
				query = 'INSERT INTO `owned_properties` SET `key` = :KEY, `char_id` = :charid',
				data = {
					KEY = key,
					charid = CharacterData.charid
				}
			})
			TriggerClientEvent("DRP_Core:Info", src, "Real Estate", "You bought this house.", 2500, true, "leftCenter")
			SyncProperties()
		else
			TriggerClientEvent("DRP_Core:Error", src, "Real Estate", "You do not have enough money in your bank.", 2500, true, "leftCenter")
		end
	end)
end

function MortgageHouse(src, Key)
	local key = Key
	local cost = Config.Properties[key].Cost
	local down = math.ceil(cost*0.05)
	local weekly = math.ceil((cost-down)/12)
	--print(weekly)
	local time = os.time(os.date('*t'))
	--print(time)
	local CharacterData = exports["drp_id"]:GetCharacterData(src)
	TriggerEvent('DRP_Bank:GetCharacterMoney', CharacterData.charid, function(characterMoney)
		local bankBalance = characterMoney.data[1].bank
		if bankBalance >= down then
			newBankBalance = bankBalance-down
			--print('Take money')
			exports['externalsql']:AsyncQuery({
				query = 'UPDATE characters SET bank = :bank WHERE id = :charid',
				data = {
					bank = newBankBalance,
					charid = CharacterData.charid
				}
			})

			exports['externalsql']:AsyncQuery({
				query = 'INSERT INTO `owned_properties` SET `key` = :KEY, `char_id` = :charid, `mortgage_payments` = :payments, `mortgage_amount` = :amount, `last_payment` = :last',
				data = {
					KEY = key,
					charid = CharacterData.charid,
					payments = 12,
					amount = weekly,
					last = time
				}
			})
			TriggerClientEvent("DRP_Core:Info", src, "Real Estate", "You mortgaged this house.", 2500, true, "leftCenter")
			SyncProperties()
		else
			TriggerClientEvent("DRP_Core:Error", src, "Real Estate", "You do not have enough money in your bank.", 2500, true, "leftCenter")
		end
	end)
end

function RemoveProperty(K)
	local key = K
	exports['externalsql']:AsyncQuery({
				query = 'DELETE FROM `owned_properties` WHERE `key` = :Key',
				data = {
					Key = key
				}
			})
	Citizen.Wait(5000)
	SyncProperties()
end

RegisterServerEvent('FD_Properties:onConnect')
AddEventHandler('FD_Properties:onConnect', function()
	local src = source
	--[[
	local PlayersProperties = {}
	local CharacterData = exports["drp_id"]:GetCharacterData(src)
	for k,v in pairs(OwnedProperties) do
		if v.char_id == CharacterData.charid then
			PlayersProperties[k] = v
		end
	end
	--print('Send Player Owned Houses')]]
	TriggerClientEvent('FD_Properties:SendProperties', src)
end)

RegisterServerEvent('FD_Properties:SetDoorStatus')
AddEventHandler('FD_Properties:SetDoorStatus', function(K, A)
	local src = source
	local key = K
	local action = A
	local CharacterData = exports["drp_id"]:GetCharacterData(src)
	--print(dump(OwnedProperties[key]))
	
	if OwnedProperties[key].char_id == CharacterData.charid then
		if action == 'unlock' then
			OwnedProperties[key].status = 0
			TriggerClientEvent("DRP_Core:Info", src, "Housing", "Door Unlocked.", 2500, true, "leftCenter")
		elseif action == 'lock' then
			OwnedProperties[key].status = 1
			TriggerClientEvent("DRP_Core:Info", src, "Housing", "Door Locked.", 2500, true, "leftCenter")
		end
	end
	for _,v in pairs(OwnedProperties[key].keys) do
		if v == CharacterData.charid then
			if action == 'unlock' then
				OwnedProperties[key].status = 0
				TriggerClientEvent("DRP_Core:Info", src, "Housing", "Door Unlocked.", 2500, true, "leftCenter")
			elseif action == 'lock' then
				OwnedProperties[key].status = 1
				TriggerClientEvent("DRP_Core:Info", src, "Housing", "Door Locked.", 2500, true, "leftCenter")
			end
			break
		end
	end
end)

RegisterServerEvent('FD_Properties:GiveKeys')
AddEventHandler('FD_Properties:GiveKeys', function(K, T)
	local src = source
	local key = K
	local target = T
	local CharacterData = exports["drp_id"]:GetCharacterData(src)
	local TargetData = exports["drp_id"]:GetCharacterData(target)
	--print(dump(TargetData))
	if OwnedProperties[key].char_id == CharacterData.charid then
		table.insert(OwnedProperties[key].keys, TargetData.charid)
		--print('Dump: ', dump(OwnedProperties[key].keys))
		exports['externalsql']:AsyncQuery({
				query = 'UPDATE `owned_properties` SET `keys` = :NewKeys WHERE `key` = :key',
				data = {
					NewKeys = json.encode(OwnedProperties[key].keys),
					key = key
				}
			})
		SyncProperties()
		TriggerClientEvent("DRP_Core:Info", src, "Housing", "You handed over a set of keys.", 2500, true, "leftCenter")
		TriggerClientEvent("DRP_Core:Info", target, "Housing", "You were handed keys.", 2500, true, "leftCenter")
	end 
end)

RegisterServerEvent('FD_Properties:ChangeLocks')
AddEventHandler('FD_Properties:ChangeLocks', function(K)
	local src = source
	local Key = K
	--print('CheckLocks')
	local CharacterData = exports["drp_id"]:GetCharacterData(src)
	if OwnedProperties[Key].char_id == CharacterData.charid then
		exports['externalsql']:AsyncQuery({
				query = 'UPDATE `owned_properties` SET `keys` = :NewKeys WHERE `key` = :key',
				data = {
					NewKeys = '{}',
					key = Key
				}
			})
		SyncProperties()
	end
	TriggerClientEvent("DRP_Core:Info", src, "Housing", "You changed the locks on your house.", 2500, true, "leftCenter")
end)

RegisterServerEvent('FD_Properties:PayMortgage')
AddEventHandler('FD_Properties:PayMortgage', function(K)
	local src = source
	local key = tonumber(K)
	local cost = OwnedProperties[key].mortgage_amount
	local payments = OwnedProperties[key].mortgage_payments
	local CharacterData = exports["drp_id"]:GetCharacterData(src)
	if OwnedProperties[key].char_id == CharacterData.charid then
		if OwnedProperties[key].mortgage_payments > 0 then
			TriggerEvent('DRP_Bank:GetCharacterMoney', CharacterData.charid, function(characterMoney)
				local bankBalance = characterMoney.data[1].bank
				if bankBalance >= cost then
					newBankBalance = bankBalance-cost
					--print('Take money')
					exports['externalsql']:AsyncQuery({
						query = 'UPDATE characters SET bank = :bank WHERE id = :charid',
						data = {
							bank = newBankBalance,
							charid = CharacterData.charid
						}
					})
					TriggerClientEvent("DRP_Core:Info", src, "Housing", "You made a Mortgage payment.", 2500, true, "leftCenter")
					local CurrentTime = os.time(os.date('*t'))
					local time = OwnedProperties[key].last_payment
					if (CurrentTime-time) > 604800 then
						--print('Insert into properties')
						exports['externalsql']:AsyncQuery({
							query = 'UPDATE `owned_properties` SET `mortgage_payments` = :payments, `last_payment` = :last WHERE `key` = :KEY',
							data = {
								payments = (payments-1),
								last = (time+604800),
								KEY = key
							}
						})
					else
						exports['externalsql']:AsyncQuery({
							query = 'UPDATE `owned_properties` SET `mortgage_payments` = :payments WHERE `key` = :KEY',
							data = {
								payments = (payments-1),
								KEY = key
							}
						})
					end
					SyncProperties()
				else
					TriggerClientEvent("DRP_Core:Error", src, "Real Estate", "You do not have enough money in your bank.", 2500, true, "leftCenter")
				end
			end)
		end
	end
end)

RegisterServerEvent('FD_Properties:SellHouse')
AddEventHandler('FD_Properties:SellHouse', function(K,A)
	local src = source
	local key = K
	local amount = A
	local CharacterData = exports["drp_id"]:GetCharacterData(src)
	if CharacterData.charid == OwnedProperties[key].char_id then
		ForSaleProperties[key] = OwnedProperties[key]
		ForSaleProperties[key].amount = amount
	end
end)

RegisterServerEvent('FD_Properties:BuyHouse')
AddEventHandler('FD_Properties:BuyHouse', function(K)
	local src = source
	local key = K
	local cost = ForSaleProperties[key].amount
	local CharacterData = exports["drp_id"]:GetCharacterData(src)
	TriggerEvent('DRP_Bank:GetCharacterMoney', CharacterData.charid, function(characterMoney)
		local bankBalance = characterMoney.data[1].bank
		if bankBalance >= cost then
			newBankBalance = bankBalance-cost
			--Take moeny from buyer
			exports['externalsql']:AsyncQuery({
				query = 'UPDATE characters SET bank = :bank WHERE id = :charid',
				data = {
					bank = newBankBalance,
					charid = CharacterData.charid
				}
			})
			--Pay Owner
			TriggerEvent('DRP_Bank:GetCharacterMoney', CharacterData.charid, function(OwnerMoney)
				local OwnerBankBalance = OwnerMoney.data[1].bank
				local NewOwnerBalace = OwnerBankBalance+cost
				exports['externalsql']:AsyncQuery({
					query = 'UPDATE characters SET bank = :bank WHERE id = :charid',
					data = {
						bank = NewOwnerBalace,
						charid = CharacterData.charid
					}
				})
			end)
			--Set new owner
			exports['externalsql']:AsyncQuery({
				query = 'UPDATE `owned_properties` SET `char_id` = :charid WHERE `key` = :KEY',
				data = {
					charid = CharacterData.charid,
					KEY = key
				}
			})
			Citizen.Wait(1000)
			TriggerClientEvent("DRP_Core:Info", src, "Real Estate", "You bought this house.", 2500, true, "leftCenter")
			SyncProperties()
		else
			TriggerClientEvent("DRP_Core:Error", src, "Real Estate", "You do not have enough money in your bank.", 2500, true, "leftCenter")
		end
	end)
end)

RegisterServerEvent('FD_Properties:SetStash')
AddEventHandler('FD_Properties:SetStash', function(K, C)
	local src = source
	local key = K
	local Coords = {x=C.x, y=C.y, z=C.z}
	print(dump(Coords))
	local CharacterData = exports["drp_id"]:GetCharacterData(src)
	if CharacterData.charid == OwnedProperties[key].char_id then
		exports['externalsql']:AsyncQuery({
				query = 'UPDATE `owned_properties` SET `stash` = :NewStash WHERE `key` = :KEY',
				data = {
					NewStash = json.encode(Coords),
					KEY = key
				}
			})
		print('Stash Set')
	end
end)

--Call Backs

DRP.NetCallbacks.Register("FD_Properties:GetAvailableHouses", function(data, send)
	send(AvailableProperties)
end)

DRP.NetCallbacks.Register('FD_Properties:GetOwned', function(data, send)
	local src = source
	--[[local PlayersProperties = {}
	local CharacterData = exports["drp_id"]:GetCharacterData(src)
	for k,v in pairs(OwnedProperties) do
		if v.char_id == CharacterData.charid then
			PlayersProperties[k] = v
		end
	end
	send(PlayersProperties)]]
	send(OwnedProperties)
end)

DRP.NetCallbacks.Register('FD_Properties:DoorStatus', function(data, send)
	local src = source
	local PlayersProperties = {['owned'] = {}, ['player'] = {}}
	PlayersProperties.owned = OwnedProperties
	local CharacterData = exports["drp_id"]:GetCharacterData(src)
	for k,v in pairs(OwnedProperties) do
		if v.char_id == CharacterData.charid then
			PlayersProperties.player[k] = v
		end
		for k2,v2 in pairs(OwnedProperties[k].keys) do
			if v2 == CharacterData.charid then
				PlayersProperties.player[k] = v
			end
		end
	end
	send(PlayersProperties)
	--print(dump(PlayersProperties))
end)

DRP.NetCallbacks.Register('FD_Properties:GetCharId', function(data, send)
	local src = source
	local CharacterData = exports["drp_id"]:GetCharacterData(src)
	send(CharacterData.charid)
end)

DRP.NetCallbacks.Register('FD_Properties:GetMortgage', function(data, send)
	local src = source
	local PlayersProperties = {}
	local time = os.time(os.date('*t'))
	local CharacterData = exports["drp_id"]:GetCharacterData(src)
	for k,v in pairs(OwnedProperties) do
		if v.char_id == CharacterData.charid then
			PlayersProperties[k] = v
			if v.last_payment ~= nil then
				if (time-604800) > v.last_payment then
					PlayersProperties[k].due = 'True'
				else
					PlayersProperties[k].due = 'False'
				end
			end
		end
	end
	--print(dump(PlayersProperties))
	send(PlayersProperties)
end)

DRP.NetCallbacks.Register('FD_Properties:BuyCost', function(data, send)
	send(ForSaleProperties)
end)

DRP.NetCallbacks.Register('FD_Properties:CanStash', function(data, send)
	local src = source
	local HasKeys = {}
	local CharacterData = exports["drp_id"]:GetCharacterData(src)
	for k,v in pairs(OwnedProperties) do
		if v.char_id == CharacterData.charid then
			HasKeys[k] = v
		end
		for k2,v2 in pairs(OwnedProperties[k].keys) do
			if v2 == CharacterData.charid then
				HasKeys[k] = v
			end
		end
	end
	send(HasKeys)
end)

--Commands


--On Resource Start
Citizen.CreateThread(function()
	Citizen.Wait(1000)
	SyncProperties()
end)
  	
Citizen.CreateThread(function()
	while true do
		Citizen.Wait(2000)
		SyncProperties()
		Citizen.Wait(5000)
		local Time = os.time(os.date('*t'))
		local Last = Time-181400
		for k,v in pairs(OwnedProperties) do
			if v.mortgage_payments > 0 then
				local Difference = Time-v.last_payment
				if Difference > 1814400 then
					RemoveProperty(v.key)
				end
			end
			Citizen.Wait(10000)
		end
		Citizen.Wait(3600000)
	end
end)

function dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

