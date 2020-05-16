OwnedProperties = {}
AvailableProperties = {}

RegisterServerEvent('fd_p:test')
AddEventHandler('fd_p:test', function()
	SyncProperties()
end)

RegisterServerEvent('fd_properties:PurchaseHouse')
AddEventHandler('fd_properties:PurchaseHouse', function(Key, paymentOption)
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
	for k,v in pairs(Properties) do
		OwnedProperties[v.key] = v
		OwnedProperties[v.key].keys = json.decode(Properties[v.key]['keys'])
	end
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
			SyncProperties()
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
			SyncProperties()
		end
	end)
end

RegisterServerEvent('fd_properties:onConnect')
AddEventHandler('fd_properties:onConnect', function()
	local src = source
	local PlayersProperties = {}
	local CharacterData = exports["drp_id"]:GetCharacterData(src)
	for k,v in pairs(OwnedProperties) do
		if v.char_id == CharacterData.charid then
			PlayersProperties[k] = v
		end
	end
	--print('Send Player Owned Houses')
	TriggerClientEvent('fd_properties:SendProperties', src, PlayersProperties)
end)

RegisterServerEvent('FD_Properties:SetDoorStatus')
AddEventHandler('FD_Properties:SetDoorStatus', function(K, A)
	local src = source
	local key = K
	local action = A
	local CharacterData = exports["drp_id"]:GetCharacterData(src)
	--print(dump(OwnedProperties[key].keys))
	
	if OwnedProperties[key].char_id == CharacterData.charid then
		if action == 'unlock' then
			OwnedProperties[key].status = 0
		elseif action == 'lock' then
			OwnedProperties[key].status = 1
		end
	end
	for _,v in pairs(OwnedProperties[key].keys) do
		if v == CharacterData.charid then
			if action == 'unlock' then
				OwnedProperties[key].status = 0
			elseif action == 'lock' then
				OwnedProperties[key].status = 1
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
	if OwnedProperties[key].char_id == CharacterData.charid then
		table.insert(OwnedProperties[key].keys, TargetData.charid)
		exports['externalsql']:AsyncQuery({
				query = 'UPDATE `owned_properties` SET `keys` = :NewKeys WHERE `key` = :key',
				data = {
					NewKeys = OwnedProperties[key].keys,
					key = key
				}
			})
		SyncProperties()
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
end)

--Call Backs

DRP.NetCallbacks.Register("fd_properties:GetAvailableHouses", function(data, send)
	send(AvailableProperties)
end)

DRP.NetCallbacks.Register('fd_properties:GetOwned', function(data, send)
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

DRP.NetCallbacks.Register('fd_properties:DoorStatus', function(data, send)
	send(OwnedProperties)
end)

DRP.NetCallbacks.Register('FD_Properties:GetCharId', function(data, send)
	local src = source
	local CharacterData = exports["drp_id"]:GetCharacterData(src)
	send(CharacterData.charid)
end)

--Commands


--On Resource Start
Citizen.CreateThread(function()
	Citizen.Wait(1000)
	SyncProperties()
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
