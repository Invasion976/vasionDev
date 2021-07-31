QBCore = nil 
TriggerEvent('QBCore:GetObject', function(obj) QBCore = obj end)

local isOpen = {}
local debug_cooldown = {}

function SendWebhookMessage(webhook,message)
	if webhook ~= nil and webhook ~= "" then
		PerformHttpRequest(webhook, function(err, text, headers) end, 'POST', json.encode({content = message}), { ['Content-Type'] = 'application/json' })
	end
end


Citizen.CreateThread(function()
	Wait(5000)
	QBCore.Functions.ExecuteSql(false,[[
		CREATE TABLE IF NOT EXISTS `trucker_available_contracts` (
			`contract_id` INT(11) UNSIGNED NOT NULL AUTO_INCREMENT,
			`contract_type` BIT(1) NOT NULL DEFAULT b'0',
			`contract_name` VARCHAR(50) NOT NULL DEFAULT '' COLLATE 'utf8mb4_general_ci',
			`coords_index` SMALLINT(6) UNSIGNED NOT NULL DEFAULT '0',
			`price_per_km` INT(10) UNSIGNED NOT NULL DEFAULT '0',
			`cargo_type` TINYINT(3) UNSIGNED NOT NULL DEFAULT '0',
			`fragile` BIT(1) NOT NULL DEFAULT b'0',
			`valuable` BIT(1) NOT NULL DEFAULT b'0',
			`fast` BIT(1) NOT NULL DEFAULT b'0',
			`truck` VARCHAR(50) NULL DEFAULT NULL COLLATE 'utf8mb4_general_ci',
			`trailer` VARCHAR(50) NOT NULL COLLATE 'utf8mb4_general_ci',
			PRIMARY KEY (`contract_id`) USING BTREE
		)
		COLLATE='utf8mb4_general_ci'
		ENGINE=InnoDB]])
	
	QBCore.Functions.ExecuteSql(false,[[
		CREATE TABLE IF NOT EXISTS `trucker_drivers` (
			`driver_id` INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
			`user_id` VARCHAR(50) NULL DEFAULT NULL,
			`name` VARCHAR(50) NOT NULL DEFAULT '' COLLATE 'utf8mb4_general_ci',
			`product_type` TINYINT(3) UNSIGNED NOT NULL DEFAULT '0',
			`distance` TINYINT(3) UNSIGNED NOT NULL DEFAULT '0',
			`valuable` TINYINT(3) UNSIGNED NOT NULL DEFAULT '0',
			`fragile` TINYINT(3) UNSIGNED NOT NULL DEFAULT '0',
			`fast` TINYINT(3) UNSIGNED NOT NULL DEFAULT '0',
			`price` INT(10) UNSIGNED NOT NULL DEFAULT '0',
			`price_per_km` INT(10) UNSIGNED NOT NULL DEFAULT '0',
			`img` VARCHAR(50) NULL DEFAULT NULL COLLATE 'utf8mb4_general_ci',
			PRIMARY KEY (`driver_id`) USING BTREE
		)
		COLLATE='utf8mb4_general_ci'
		ENGINE=InnoDB]])
	
	QBCore.Functions.ExecuteSql(false,[[	
		CREATE TABLE IF NOT EXISTS `trucker_loans` (
			`id` INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
			`user_id` VARCHAR(50) NOT NULL,
			`loan` INT(10) UNSIGNED NOT NULL DEFAULT '0',
			`remaining_amount` INT(10) UNSIGNED NOT NULL DEFAULT '0',
			`day_cost` INT(10) UNSIGNED NOT NULL DEFAULT '0',
			`taxes_on_day` INT(10) UNSIGNED NOT NULL DEFAULT '0',
			`timer` INT(10) UNSIGNED NOT NULL DEFAULT '0',
			PRIMARY KEY (`id`) USING BTREE
		)
		COLLATE='utf8mb4_general_ci'
		ENGINE=InnoDB]])
	
	QBCore.Functions.ExecuteSql(false,[[	
		CREATE TABLE IF NOT EXISTS `trucker_trucks` (
			`truck_id` INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
			`user_id` VARCHAR(50) NOT NULL,
			`truck_name` VARCHAR(50) NOT NULL COLLATE 'utf8mb4_general_ci',
			`driver` INT(10) UNSIGNED NULL DEFAULT NULL,
			`body` SMALLINT(5) UNSIGNED NOT NULL DEFAULT '1000',
			`engine` SMALLINT(5) UNSIGNED NOT NULL DEFAULT '1000',
			`transmission` SMALLINT(5) UNSIGNED NOT NULL DEFAULT '1000',
			`wheels` SMALLINT(5) UNSIGNED NOT NULL DEFAULT '1000',
			PRIMARY KEY (`truck_id`) USING BTREE
		)
		COLLATE='utf8mb4_general_ci'
		ENGINE=InnoDB]])
	QBCore.Functions.ExecuteSql(false,[[	
		CREATE TABLE IF NOT EXISTS `trucker_users` (
			`user_id` VARCHAR(50) NOT NULL,
			`money` INT(10) UNSIGNED NOT NULL DEFAULT '0',
			`total_earned` INT(10) UNSIGNED NOT NULL DEFAULT '0',
			`finished_deliveries` INT(10) UNSIGNED NOT NULL DEFAULT '0',
			`exp` INT(10) UNSIGNED NOT NULL DEFAULT '0',
			`traveled_distance` DOUBLE UNSIGNED NOT NULL DEFAULT '0',
			`skill_points` INT(10) UNSIGNED NOT NULL DEFAULT '0',
			`product_type` TINYINT(3) UNSIGNED NOT NULL DEFAULT '0',
			`distance` TINYINT(3) UNSIGNED NOT NULL DEFAULT '0',
			`valuable` TINYINT(3) UNSIGNED NOT NULL DEFAULT '0',
			`fragile` TINYINT(3) UNSIGNED NOT NULL DEFAULT '0',
			`fast` TINYINT(3) UNSIGNED NOT NULL DEFAULT '0',
			`loan_notify` BIT(1) NOT NULL DEFAULT b'0',
			PRIMARY KEY (`user_id`) USING BTREE
		)
		COLLATE='utf8mb4_general_ci'
		ENGINE=InnoDB]])
end)


-- Gera contratos
Citizen.CreateThread(function()
	local contract_type = 1
	Citizen.Wait(10000)
	while true do
		if contract_type == 0 then
			contract_type = 1
			bonus = Config.contracts.shipping_multiplier
		else
			contract_type = 0
			bonus = 1.0
		end
		local coords = math.random(1, #Config.delivery_locations)
		local price_per_km = math.random(Config.contracts['price_per_km_min'], Config.contracts['price_per_km_max'])
		
		local truck = Config.contracts.trucks[math.random(1, #Config.contracts.trucks)]    
		local loads = Config.contracts.cargo[math.random(1, #Config.contracts.cargo)]
		local contract_name = loads.name
		local trailer = loads.carga
		local cargo_type = loads.def[1]
		local fragile = loads.def[2]
		local valuable = loads.def[3]
		
		local cargo_urgent = math.random(0,100)
		local fast = 0
		if cargo_urgent <= Config.contracts.probability_be_urgent_load then
			fast = 1
		end

		if contract_type == 1 then truck = 'nil' end

		local sql = "SELECT COUNT(contract_id) as qtd FROM `trucker_available_contracts`"
		local count = QBCore.Functions.ExecuteSql(true, sql)[1]
        count = count.qtd
		truck = ("'" .. truck .. "'")
            
		if count >= Config.contracts.max_active_contracts then
			local sql = "SELECT MIN(contract_id) as min FROM trucker_available_contracts"
			local min = QBCore.Functions.ExecuteSql(true,sql)[1]
            min = min.min   

			
			local sql = "DELETE FROM `trucker_available_contracts` WHERE contract_id = " .. min
			QBCore.Functions.ExecuteSql(false, sql)
		end

		local sql = "INSERT INTO `trucker_available_contracts` (contract_type, contract_name, coords_index, price_per_km, cargo_type, fragile, valuable, fast, truck, trailer) VALUES (" .. contract_type .. ", '" .. contract_name .. "', " .. coords .. ", " .. (price_per_km*bonus) .. ", " .. cargo_type .. ", " .. fragile .. ", " .. valuable .. ", " .. fast .. ", " .. truck .. ", '" .. trailer .. "')"
		QBCore.Functions.ExecuteSql(false, sql)
            
		local users = QBCore.Functions.GetPlayers()
		for k,v in pairs(users) do
			if isOpen[v] then
				openUI(v, true)
				Citizen.Wait(100)
			end
		end

		Citizen.Wait(Config.contracts.cooldown*1000*60)
	end
end)

-- generates drivers
Citizen.CreateThread(function()
	Citizen.Wait(10000)
	while true do 
		local product_type = math.random(0, 6)
		local distance = math.random(0, 6)
		local fragile = math.random(0, 6)
		local valuable = math.random(0, 6)
		local fast = math.random(0, 6)
		if product_type+distance+fragile+valuable+fast > 15 then
			product_type = math.random(0, 6)
			distance = math.random(0, 6)
			fragile = math.random(0, 6)
			valuable = math.random(0, 6)
			fast = math.random(0, 6)
			if product_type+distance+fragile+valuable+fast > 20 then
				product_type = math.random(0, 6)
				distance = math.random(0, 6)
				fragile = math.random(0, 6)
				valuable = math.random(0, 6)
				fast = math.random(0, 6)
			end
		end
		
		local price = math.random(Config.drivers.price_min, Config.drivers.price_max)
		price = price + (product_type+distance+fragile+valuable+fast)*(price*(Config.drivers.percentage_bonus_skills/100))
		local price_per_km = math.random(Config.drivers.price_per_km_min, Config.drivers.price_per_km_max)
		price_per_km = price_per_km + (product_type+distance+fragile+valuable+fast)*(price_per_km*(Config.drivers.percentage_bonus_skills/100))
		
		local driver = Config.drivers.names[math.random(1, #Config.drivers.names)]
		local name = driver.names[math.random(1, #driver.names)]

		if contract_type == 1 then truck = nil end

		local sql = "SELECT COUNT(driver_id) as qtd FROM trucker_drivers WHERE user_id IS NULL"
		local count = QBCore.Functions.ExecuteSql(true, sql)[1]
        count = count.qtd
		
		if count >= Config.drivers.max_active_drivers then
			local sql = "SELECT MIN(driver_id) as min FROM trucker_drivers WHERE user_id IS NULL"
			local min = QBCore.Functions.ExecuteSql(true, sql)[1]
            min = min.min
			
			local sql = "DELETE FROM `trucker_drivers` WHERE driver_id = " .. min
			QBCore.Functions.ExecuteSql(false, sql)
		end

		local sql = "INSERT INTO `trucker_drivers` (user_id, name, product_type, distance, fragile, valuable, fast, price, price_per_km, img) VALUES (NULL, '" .. name .. "', " .. product_type .. ", " .. distance .. ", " .. fragile .. ", " .. valuable .. ", " .. fast .. ", " .. price .. ", " .. price_per_km .. ", '" .. driver.img .. "')"
		QBCore.Functions.ExecuteSql(false, sql)
		
		local users = QBCore.Functions.GetPlayers()
		for k,v in pairs(users) do
			if isOpen[v] then
				openUI(v, true)
				Citizen.Wait(100)
			end
		end
		
		Citizen.Wait(Config.drivers.cooldown*1000*60)
	end
end)

-- Generates work for drivers
Citizen.CreateThread(function()
	Citizen.Wait(10000)
	while true do 
		local sql = [[SELECT d.driver_id, d.user_id, d.name, d.product_type, d.distance, d.valuable, d.fragile, d.fast, d.price, d.price_per_km 
					FROM trucker_trucks t
						INNER JOIN trucker_drivers d ON (t.driver = d.driver_id)
					WHERE t.driver <> 0 AND t.driver IS NOT NULL]]
		local data = QBCore.Functions.ExecuteSql(true, sql)
		for k,v in pairs(data) do
			local source = source --QBCore.Functions.GetPlayerByCitizenId(tonumber(v.user_id))
            local user_id = QBCore.Functions.GetPlayer(Source)
            user_id = user_id.PlayerData.citizenid
                
			if Config.works.generates_money_offline or source then
				if tryGetTruckerMoney(v.user_id,v.price + v.price_per_km) then
					local amount = math.random(Config.works.initial_value_min,Config.works.initial_value_max)
					amount = amount + (v.product_type+v.distance+v.fragile+v.valuable+v.fast)*(amount*(Config.works.percentage_bonus_skills/100))
					giveTruckerMoney(v.user_id,amount)
				else
					local sql = "UPDATE `trucker_drivers` SET user_id = NULL WHERE driver_id = " .. v.driver_id
					QBCore.Functions.ExecuteSql(false, sql)
					local sql = "UPDATE `trucker_trucks` SET driver = NULL WHERE driver = '" .. v.driver_id
					QBCore.Functions.ExecuteSql(false, sql)
					if source then
						TriggerClientEvent("Notify",source,"denied",Lang[Config.lang]['driver_failed']:format(v.name))
					end
				end

			
				if source then
					if isOpen[source] then
						openUI(source, true)
						Citizen.Wait(100)
					end
				end
			end
			Citizen.Wait(100)
		end
		Citizen.Wait(Config.works.cooldown*1000*60)
	end
end)

-- Paga empréstimo
Citizen.CreateThread(function()
	Citizen.Wait(10000)
	while true do
		local sql = "SELECT * FROM trucker_loans"
		local data = QBCore.Functions.ExecuteSql(true, sql)
		for k,v in pairs(data) do
			if v.timer + Config.loans.cooldown < os.time() then
				local source = QBCore.Functions.GetPlayerByCitizenId(tonumber(v.user_id))
				if tryGetTruckerMoney(v.user_id,v.day_cost) then
					local new_loan = v.remaining_amount - v.taxes_on_day
					if new_loan > 0 then
						local sql = "UPDATE `trucker_loans` SET remaining_amount = " .. new_loan .. ", timer = " .. os.time() .. " WHERE id = " .. v.id
						QBCore.Functions.ExecuteSql(false, sql)
					else
						local sql = "DELETE FROM `trucker_loans` WHERE id = " .. v.id .. 
						QBCore.Functions.ExecuteSql(false, sql)
					end
				else
					if source then
						TriggerClientEvent("Notify",source,"important",Lang[Config.lang]['no_loan_money'])
					else
						local sql = "UPDATE `trucker_users` SET loan_notify = 1 WHERE user_id = '" .. v.user_id
						QBCore.Functions.ExecuteSql(false, sql)
					end
				end
				if source then
					if isOpen[source] then
						openUI(source, true)
						Citizen.Wait(100)
					end
				end
				Citizen.Wait(100)
			end
		end
		Citizen.Wait(10*1000*60)
	end
end)

RegisterServerEvent("truck_logistics:getData")
AddEventHandler("truck_logistics:getData",function()
	local source = source
	--print(QBCore.Functions.GetPlayer(src).identifier)
	local user_id = QBCore.Functions.GetPlayer(source).PlayerData.citizenid
 	
    if user_id then
        isOpen[source] = true
        openUI(source, false)
    end
end)

RegisterServerEvent("truck_logistics:closeUI")
AddEventHandler("truck_logistics:closeUI",function()
	isOpen[source] = false
end)

RegisterServerEvent("truck_logistics:startContract")
AddEventHandler("truck_logistics:startContract",function(data)
	local id = data.id
	local distance = data.distance
	local reward = data.reward

	local source = source
	if debug_cooldown[source] == nil then
		debug_cooldown[source] = true
        
        local xPlayer = QBCore.Functions.GetPlayer(source)
        user_id = xPlayer.PlayerData.citizenid
		if user_id then
			local sql = "SELECT * FROM `trucker_available_contracts` WHERE contract_id = " .. id
			local query = QBCore.Functions.ExecuteSql(true, sql)
			if query and query[1] then
				local sql = "SELECT * FROM `trucker_users` WHERE user_id = '" .. user_id .. "'"
				query_users = QBCore.Functions.ExecuteSql(true, sql)
				if query_users and query_users[1] then
					if tonumber(query_users[1].product_type) >= tonumber(query[1].cargo_type) then
						if tonumber(query_users[1].fragile) >= tonumber(query[1].fragile) then
							if tonumber(query_users[1].valuable) >= tonumber(query[1].valuable) then
								if tonumber(query_users[1].fast) >= tonumber(query[1].fast) then
									if Config.distance_skill[tonumber(query_users[1].distance)] >= tonumber(distance) then
										if tonumber(query[1].contract_type) == 0 then
											-- start work
											TriggerClientEvent("truck_logistics:startContract",source,query[1],distance,reward,{})
										else
											-- check if there is a truck
											local sql = "SELECT * FROM `trucker_trucks` WHERE driver = 0 AND user_id = '" .. user_id .. "'"
											query_truck = QBCore.Functions.ExecuteSql(true, sql)
											if query_truck and query_truck[1] then
												TriggerClientEvent("truck_logistics:startContract",source,query[1],distance,reward,query_truck[1])
											else
												TriggerClientEvent("Notify",source,"denied",Lang[Config.lang]['own_truck'])
											end
										end
									else
										TriggerClientEvent("Notify",source,"denied",Lang[Config.lang]['no_skill_1'])
									end
								else
									TriggerClientEvent("Notify",source,"denied",Lang[Config.lang]['no_skill_2'])
								end
							else
								TriggerClientEvent("Notify",source,"denied",Lang[Config.lang]['no_skill_3'])
							end
						else
							TriggerClientEvent("Notify",source,"denied",Lang[Config.lang]['no_skill_4'])
						end
					else
						TriggerClientEvent("Notify",source,"denied",Lang[Config.lang]['no_skill_5'])
					end
				end
			else
				TriggerClientEvent("Notify",source,"denied",Lang[Config.lang]['job_already_started'])
			end
		end
		debug_cooldown[source] = nil
	end
end)

RegisterServerEvent("truck_logistics:spawnTruck")
AddEventHandler("truck_logistics:spawnTruck",function(truck_id)
	local source = source
	if debug_cooldown[source] == nil then
		debug_cooldown[source] = true
        local xPlayer = QBCore.Functions.GetPlayer(source)
        local user_id = xPlayer.PlayerData.citizenid
		if user_id then
			local sql = "SELECT * FROM `trucker_trucks` WHERE truck_id = " .. tonumber(truck_id)
			query_truck = QBCore.Functions.ExecuteSql(true, sql)
			if query_truck and query_truck[1] then
				TriggerClientEvent("truck_logistics:spawnTruck",source,query_truck[1])
			end
		end
		debug_cooldown[source] = nil
	end
end)

RegisterServerEvent("truck_logistics:upgradeSkill")
AddEventHandler("truck_logistics:upgradeSkill",function(data)
	local source = source
	local user_id = QBCore.Functions.GetPlayer(source)
    user_id = user_id.PlayerData.citizenid
	if user_id then
		local sql = "SELECT * FROM `trucker_users` WHERE user_id = '" .. user_id .. "'"
		local query = QBCore.Functions.ExecuteSql(true, sql)[1]
        print("data.value: ",data.value)
        print("data.id: ",data.id)
        print("query[data.id]: ",query[data.id])
		if query.skill_points >= (data.value - query[data.id]) then
			local sql = "UPDATE `trucker_users` SET " .. data.id .. " = " .. data.value .. ", skill_points = " .. (query.skill_points - (data.value - query[data.id])) .. " WHERE user_id = '" .. user_id .. "'"
			QBCore.Functions.ExecuteSql(false, sql)
			TriggerClientEvent("Notify",source,"success",Lang[Config.lang]['upgraded_skill'])
			openUI(source,true)
		else
			TriggerClientEvent("Notify",source,"denied",Lang[Config.lang]['insufficient_skill_points'])
		end
	end
end)

RegisterServerEvent("truck_logistics:repairTruck")
AddEventHandler("truck_logistics:repairTruck",function(item)
	local source = source
	local user_id = QBCore.Functions.GetPlayer(source)
    user_id = user_id.PlayerData.citizenid
	if user_id then
		local sql = "SELECT * FROM `trucker_trucks` WHERE user_id = '" .. user_id .. "' AND driver = 0";
		local query = QBCore.Functions.ExecuteSql(true, sql)[1]
		if query then
			local amount = math.floor((100-(tonumber(query[item])/10)) * Config.repair_value[item])
			if amount > 0 then
				if tryGetTruckerMoney(user_id,amount) then
					local sql = "UPDATE `trucker_trucks` SET " .. item .. " = 1000 WHERE user_id = '" .. user_id .. "' AND driver = 0";
					QBCore.Functions.ExecuteSql(false, sql)
					TriggerClientEvent("Notify",source,"success",Lang[Config.lang]['repaired'])
					openUI(source,true)
				else
					TriggerClientEvent("Notify",source,"denied",Lang[Config.lang]['insufficiente_funds'])
				end
			else
				TriggerClientEvent("Notify",source,"denied",Lang[Config.lang]['not_repaired'])
			end
		else
			TriggerClientEvent("Notify",source,"denied",Lang[Config.lang]['have_no_truck'])
		end
	end
end)

RegisterServerEvent("truck_logistics:buyTruck")
AddEventHandler("truck_logistics:buyTruck",function(data)
	local source = source
	local user_id = QBCore.Functions.GetPlayer(source)
    user_id = user_id.PlayerData.citizenid
	if user_id then
		if tryGetTruckerMoney(user_id,tonumber(data.price)) then
			local sql = "INSERT INTO `trucker_trucks` (user_id, truck_name, driver) VALUES ('" .. user_id .. "','" .. data.truck_name .. "', NULL)"
			QBCore.Functions.ExecuteSql(false, sql)
			TriggerClientEvent("Notify",source,"success",Lang[Config.lang]['bought'])
			SendWebhookMessage(Config.webhook,Lang[Config.lang]['logs_buytruck']:format(data.truck_name,data.price,user_id..os.date("\n["..Lang[Config.lang]['logs_date'].."]: %d/%m/%Y ["..Lang[Config.lang]['logs_hour'].."]: %H:%M:%S")))
			openUI(source,true)
		else
			TriggerClientEvent("Notify",source,"denied",Lang[Config.lang]['insufficient_funds'])
		end
	end
end)

RegisterServerEvent("truck_logistics:sellTruck")
AddEventHandler("truck_logistics:sellTruck",function(data)
	local source = source
	if debug_cooldown[source] == nil then
		debug_cooldown[source] = true
		local user_id = QBCore.Functions.GetPlayer(source)
        user_id = user_id.PlayerData.citizenid
		if user_id then
			local sql = "SELECT * FROM `trucker_trucks` WHERE truck_id = " .. data.truck_id
			local query = QBCore.Functions.ExecuteSql(true, sql)[1]
			if query then 
				local sql = "DELETE FROM `trucker_trucks` WHERE truck_id = " .. data.truck_id
				QBCore.Functions.ExecuteSql(false, sql)
				local amount = math.floor(tonumber(Config.dealership[data.truck_name].price * Config.sale_multiplier))
				giveTruckerMoney(user_id,amount)
				TriggerClientEvent("Notify",source,"success",Lang[Config.lang]['sold'])
				SendWebhookMessage(Config.webhook,Lang[Config.lang]['logs_selltruck']:format(data.truck_name,amount,user_id..os.date("\n["..Lang[Config.lang]['logs_date'].."]: %d/%m/%Y ["..Lang[Config.lang]['logs_hour'].."]: %H:%M:%S")))
				openUI(source,true)
			end
		end
		debug_cooldown[source] = nil
	end
end)

RegisterServerEvent("truck_logistics:hireDriver")
AddEventHandler("truck_logistics:hireDriver",function(driver_id)
	local source = source
	local user_id = QBCore.Functions.GetPlayer(source)
    user_id = user_id.PlayerData.citizenid
	if user_id then
		local sql = "SELECT COUNT(driver_id) as qtd FROM trucker_drivers WHERE user_id = '" .. user_id .. "'"
		local count = QBCore.Functions.ExecuteSql(true, sql)[1]
        count = count.qtd
		
		if count <= Config.drivers.max_drivers_per_player then
			local sql = "SELECT price FROM trucker_drivers WHERE driver_id = " .. driver_id
			local query = QBCore.Functions.ExecuteSql(true, sql)[1]
            
			if tryGetTruckerMoney(user_id,query.price) then
				local sql = "UPDATE `trucker_drivers` SET user_id = '" .. user_id .. "' WHERE driver_id = " .. driver_id
				QBCore.Functions.ExecuteSql(false, sql)
				TriggerClientEvent("Notify",source,"success",Lang[Config.lang]['hired'])
				openUI(source,true)
			else
				TriggerClientEvent("Notify",source,"denied","Insufficient money")
			end
		else
			TriggerClientEvent("Notify",source,"denied",Lang[Config.lang]['max_drivers'])
		end
	end
end)

RegisterServerEvent("truck_logistics:fireDriver")
AddEventHandler("truck_logistics:fireDriver",function(driver_id)
	local source = source
	local user_id = QBCore.Functions.GetPlayer(source)
    user_id = user_id.PlayerData.citizenid
	if user_id then
		local sql = "UPDATE `trucker_drivers` SET user_id = NULL WHERE driver_id = " .. driver_id
		QBCore.Functions.ExecuteSql(false, sql)
		local sql = "UPDATE `trucker_trucks` SET driver = NULL WHERE driver = " .. driver_id
		QBCore.Functions.ExecuteSql(false, sql)
		TriggerClientEvent("Notify",source,"success",Lang[Config.lang]['fired'])
		openUI(source,true)
	end
end)

RegisterServerEvent("truck_logistics:setDriver")
AddEventHandler("truck_logistics:setDriver",function(data)
	local source = source
	local user_id = QBCore.Functions.GetPlayer(source)
    user_id = user_id.PlayerData.citizenid
        
	if user_id then
		if tonumber(data.driver_id) ~= 0 then
			local sql = "UPDATE `trucker_trucks` SET driver = NULL WHERE driver = " .. data.driver_id
			QBCore.Functions.ExecuteSql(false, sql)
		end
		local sql = "UPDATE `trucker_trucks` SET driver = " .. data.driver_id .. " WHERE truck_id = " .. data.truck_id
		QBCore.Functions.ExecuteSql(false, sql)
		openUI(source,true)
	end
end)

RegisterServerEvent("truck_logistics:withdrawMoney")
AddEventHandler("truck_logistics:withdrawMoney",function()
	local source = source
	if debug_cooldown[source] == nil then
		debug_cooldown[source] = true
		local xPlayer = QBCore.Functions.GetPlayer(source)
		local user_id = xPlayer.PlayerData.citizenid
		if user_id then
			local sql = "SELECT * FROM `trucker_loans` WHERE user_id = '" .. user_id .. "'"
			local query = QBCore.Functions.ExecuteSql(true,sql)[1]
			if not query or not query.remaining_amount or query.remaining_amount <= 0 then
				local sql = "SELECT money FROM `trucker_users` WHERE user_id = '" .. user_id .. "'"
				local query = QBCore.Functions.ExecuteSql(true,sql)[1]
				local amount = tonumber(query.money)
				if amount and amount > 0 then
					local sql = "UPDATE `trucker_users` SET money = 0 WHERE user_id = '" .. user_id .. "'"
					QBCore.Functions.ExecuteSql(false,sql)
					xPlayer.Functions.AddMoney('bank', amount)
					TriggerClientEvent("Notify",source,"success",Lang[Config.lang]['money_withdrawn'])
					openUI(source,true)
				else
					TriggerClientEvent("Notify",source,"denied",Lang[Config.lang]['insufficient_money'])
				end
			else
				TriggerClientEvent("Notify",source,"denied",Lang[Config.lang]['pay_loans'])
			end
		end
		debug_cooldown[source] = nil
	end
end)

RegisterServerEvent("truck_logistics:depositMoney")
AddEventHandler("truck_logistics:depositMoney",function(data)
	local source = source
	local xPlayer = QBCore.Functions.GetPlayer(source)
	local user_id = xPlayer.PlayerData.citizenid

	if user_id then
		local amount = tonumber(data.amount)
		if amount and amount > 0 then
			money = xPlayer.PlayerData.money.bank
			if money >= amount then
				xPlayer.Functions.RemoveMoney('bank', amount)
				giveTruckerMoney(user_id,amount)
				TriggerClientEvent("Notify",source,"success",Lang[Config.lang]['money_deposited'])
				openUI(source,true)
			else
				TriggerClientEvent("Notify",source,"denied",Lang[Config.lang]['insufficient_money'])
			end
		else
			TriggerClientEvent("Notify",source,"denied",Lang[Config.lang]['invalid_value'])
		end
	end
end)

RegisterServerEvent("truck_logistics:loan")
AddEventHandler("truck_logistics:loan",function(data)
	local source = source
	if debug_cooldown[source] == nil then
		debug_cooldown[source] = true
		local user_id = QBCore.Functions.GetPlayer(source)
        user_id = user_id.PlayerData.citizenid
		if user_id then
			local sql = "SELECT * FROM `trucker_loans` WHERE user_id = '" .. user_id .. "'"
			local query = QBCore.Functions.ExecuteSql(true,sql)
			local amount_loans = 0;
			for k,v in pairs(query) do
				amount_loans = amount_loans + tonumber(v.loan)
			end
			
			if amount_loans + Config.loans.values[data.loan_id][1] <= getMaxLoan(user_id) then
				local sql = "INSERT INTO `trucker_loans` (user_id,loan,remaining_amount,day_cost,taxes_on_day) VALUES ('" .. user_id .. "'," .. Config.loans.values[data.loan_id][1] .. "," .. Config.loans.values[data.loan_id][1] .. "," .. Config.loans.values[data.loan_id][2] .. "," .. Config.loans.values[data.loan_id][3] .. ")"
				QBCore.Functions.ExecuteSql(false,sql)
                        --, {['@user_id'] = user_id, ['@loan'] = Config.loans.values[data.loan_id][1], ['@remaining_amount'] = Config.loans.values[data.loan_id][1], ['@day_cost'] = Config.loans.values[data.loan_id][2], ['@taxes_on_day'] = Config.loans.values[data.loan_id][3]});
				giveTruckerMoney(user_id,Config.loans.values[data.loan_id][1])
				TriggerClientEvent("Notify",source,"success",Lang[Config.lang]['loan'])
				openUI(source,true)
			else
				TriggerClientEvent("Notify",source,"denied",Lang[Config.lang]['no_loan'])
			end
		end
		debug_cooldown[source] = nil
	end
end)

RegisterServerEvent("truck_logistics:payLoan")
AddEventHandler("truck_logistics:payLoan",function(data)
	local source = source
	local user_id = QBCore.Functions.GetPlayer(source)
    user_id = user_id.PlayerData.citizenid
	if user_id then
		local sql = "SELECT * FROM `trucker_loans` WHERE id = '" .. data.loan_id
		local query = QBCore.Functions.ExecuteSql(true,sql)[1]
		if tryGetTruckerMoney(user_id,query.remaining_amount) then
			local sql = "DELETE FROM `trucker_loans` WHERE id = '" .. data.loan_id
			QBCore.Functions.ExecuteSql(false,sql)
			TriggerClientEvent("Notify",source,"success",Lang[Config.lang]['loan_paid'])
			openUI(source,true)
		else
			TriggerClientEvent("Notify",source,"denied",Lang[Config.lang]['insufficient_funds'])
		end
	end
end)

RegisterServerEvent("truck_logistics:finishJob")
AddEventHandler("truck_logistics:finishJob",function(data,distance,reward,truck_data,truck_engine,truck_body,trailer_body)
	local source = source
	local user_id = QBCore.Functions.GetPlayer(source)
    user_id = user_id.PlayerData.citizenid
        
	if user_id then
		trailer_body = trailer_body/1000
		local exp_amount = reward*(Config.exp/100)
		local bonus = 0
		local bonus_exp = 0
		local level = getPlayerLevel(user_id)
		local sql = "SELECT * FROM `trucker_users` WHERE user_id = '" .. user_id .. "'"
		local query = QBCore.Functions.ExecuteSql(true,sql)[1]
		if data.fragile > 0 then
			bonus = bonus + reward*(Config.bonus['fragile']['cash'][query.fragile]/100)
			bonus_exp = bonus_exp + exp_amount*(Config.bonus['fragile']['exp'][query.fragile]/100)
		end
		if data.valuable > 0 then
			bonus = bonus + reward*(Config.bonus['valuable']['cash'][query.valuable]/100)
			bonus_exp = bonus_exp + exp_amount*(Config.bonus['valuable']['exp'][query.valuable]/100)
		end
		if data.fast > 0 then
			bonus = bonus + reward*(Config.bonus['fast']['cash'][query.fast]/100)
			bonus_exp = bonus_exp + exp_amount*(Config.bonus['fast']['exp'][query.fast]/100)
		end
		if distance > Config.distance_skill[0] then
			if Config.bonus['distance']['cash'][query.distance] then
				bonus = bonus + reward*(Config.bonus['distance']['cash'][query.distance]/100)
				bonus_exp = bonus_exp + exp_amount*(Config.bonus['distance']['exp'][query.distance]/100)
			end
		end
		local received_amount = math.floor((reward + bonus)*trailer_body)
		local received_xp = math.floor((exp_amount + bonus_exp)*trailer_body)

		if truck_data.truck_id then
			local sql = "UPDATE `trucker_trucks` SET engine = '" .. truck_engine .. "', transmission = " .. math.floor((truck_engine + truck_body)/2) .. ", body = '" .. truck_body .. "', wheels = wheels - " .. tonumber(string.format("%.2f", distance))*10 .. " WHERE truck_id = " .. truck_data.truck_id
			QBCore.Functions.ExecuteSql(false,sql)
                    --{['@engine'] = truck_engine, ['@body'] = truck_body, ['@transmission'] = math.floor((truck_engine + truck_body)/2), ['@wheels'] = tonumber(string.format("%.2f", distance))*10, ['@truck_id'] = truck_data.truck_id});
		end
		local sql = "UPDATE `trucker_users` SET total_earned = total_earned + " .. received_amount .. ", finished_deliveries = finished_deliveries + 1, traveled_distance = traveled_distance + " .. tonumber(string.format("%.2f", distance)) .. ", exp = exp + " .. received_xp .. " WHERE user_id = '" .. user_id .. "'"
		QBCore.Functions.ExecuteSql(false,sql)
                --, {['@reward'] = received_amount, ['@distance'] = tonumber(string.format("%.2f", distance)), ['@exp_amount'] = received_xp, ['@user_id'] = user_id});

		giveTruckerMoney(user_id,received_amount)
		TriggerClientEvent("Notify",source,"success",Lang[Config.lang]['reward']:format(tostring(received_amount),tostring(trailer_body*100),tostring(received_xp)))
		local level2 = getPlayerLevel(user_id)
		if level2 - level > 0 then
			local sql = "UPDATE `trucker_users` SET skill_points = skill_points + " .. (level2 - level) .. " WHERE user_id = '" .. user_id .. "'"
			QBCore.Functions.ExecuteSql(false,sql)
			SendWebhookMessage(Config.webhook,Lang[Config.lang]['logs_skill']:format((level2 - level),user_id..os.date("\n["..Lang[Config.lang]['logs_date'].."]: %d/%m/%Y ["..Lang[Config.lang]['logs_hour'].."]: %H:%M:%S")))
		end
		SendWebhookMessage(Config.webhook,Lang[Config.lang]['logs_finish']:format(tostring(received_amount),tostring(received_xp),user_id..os.date("\n["..Lang[Config.lang]['logs_date'].."]: %d/%m/%Y ["..Lang[Config.lang]['logs_hour'].."]: %H:%M:%S")))
	end
end)

RegisterServerEvent("truck_logistics:updateTruckStatus")
AddEventHandler("truck_logistics:updateTruckStatus",function(truck_data,truck_engine,truck_body)
	local source = source
	local user_id = QBCore.Functions.GetPlayer(source)
    user_id = user_id.PlayerData.citizenid
	if user_id then
		if truck_data.truck_id then
			local sql = "UPDATE `trucker_trucks` SET engine = " .. truck_engine .. ", transmission = " .. math.floor((truck_engine + truck_body)/2) .. ", body = " .. truck_body .. " WHERE truck_id = " .. truck_data.truck_id
			QBCore.Functions.ExecuteSql(false,sql)
		end
	end
end)

RegisterServerEvent("truck_logistics:deleteContract")
AddEventHandler("truck_logistics:deleteContract",function(id)
	local source = source
	local user_id = QBCore.Functions.GetPlayer(source)
    user_id = user_id.PlayerData.citizenid
	if user_id then
		local sql = "DELETE FROM `trucker_available_contracts` WHERE contract_id = " .. id
		QBCore.Functions.ExecuteSql(false,sql)
		local users = QBCore.Functions.GetPlayers()
		for k,v in pairs(users) do
			if isOpen[v] then
				openUI(v,true)
			end
		end
	end
end)

function giveTruckerMoney(user_id,amount)
	local sql = "UPDATE `trucker_users` SET money = money + " .. amount .. " WHERE user_id = '" .. user_id .. "'"
	QBCore.Functions.ExecuteSql(false,sql)
end

function tryGetTruckerMoney(user_id,amount)
	local sql = "SELECT money FROM `trucker_users` WHERE user_id = '" .. user_id .. "'"
	local query = QBCore.Functions.ExecuteSql(true, sql)[1]
    
    print(amount)
    
	if tonumber(query.money) >= amount then
		local sql = "UPDATE `trucker_users` SET money = " ..(tonumber(query.money) - amount).. " WHERE user_id = '" .. user_id .. "'"
		QBCore.Functions.ExecuteSql(false, sql)
		return true
	else
		return false
	end
end

function getMaxLoan(user_id)
	local max_loan = 0;
	local level = getPlayerLevel(user_id)
	for k,v in pairs(Config.max_loan_per_level) do
		if k <= level then
			max_loan = v
		end
	end
	return max_loan
end

function getPlayerLevel(user_id)
	local sql = "SELECT exp FROM `trucker_users` WHERE user_id = '" .. user_id .. "'"
	local query = QBCore.Functions.ExecuteSql(true, sql)[1]
	local level = 0
	if query then
		for k,v in pairs(Config.exp_per_level) do
			if tonumber(query.exp) >= v then
				level = k
			else
				return level
			end
		end
	end
	return level
end

function openUI(source, reset)
	local query = {}
	local xPlayer = QBCore.Functions.GetPlayer(source)
	if xPlayer then
		local user_id = xPlayer.PlayerData.citizenid
        
		if user_id then
			-- Search user data
			local sql = "SELECT * FROM `trucker_users` WHERE `user_id` = '" .. user_id .. "'"
			local users_data = QBCore.Functions.ExecuteSql(true, sql)
            query.trucker_users = users_data[1] or nil
            
			if query.trucker_users == nil then
				local sql = "INSERT INTO `trucker_users` (user_id) VALUES ('" .. user_id .. "')"
				QBCore.Functions.ExecuteSql(false, sql)
				local sql = "SELECT * FROM `trucker_users` WHERE user_id =  '" .. user_id .. "'"
				query.trucker_users = QBCore.Functions.ExecuteSql(true, sql)
			else
				if query.trucker_users.loan_notify == 1 then
					local sql = "UPDATE `trucker_users` SET loan_notify = 0 WHERE user_id = '" .. user_id .. "'"
					QBCore.Functions.ExecuteSql(false, sql)
					TriggerClientEvent("Notify",source,"important",Lang[Config.lang]['no_loan_money'])
				end
			end

			-- Busca os contratos
			local sql = "SELECT * FROM `trucker_available_contracts`"
			query.trucker_available_contracts = QBCore.Functions.ExecuteSql(true, sql)

			-- Busca os caminhões
			local sql = "SELECT * FROM `trucker_trucks` WHERE user_id = '" .. user_id .. "'"
			query.trucker_trucks = QBCore.Functions.ExecuteSql(true, sql)

			-- Busca os motoristas
			local sql = "SELECT * FROM `trucker_drivers` WHERE user_id = '" .. user_id .. "' OR user_id IS NULL"
			query.trucker_drivers = QBCore.Functions.ExecuteSql(true, sql)

			-- Busca os emprestimos
			local sql = "SELECT * FROM `trucker_loans` WHERE user_id = '" .. user_id .. "'"
			query.trucker_loans = QBCore.Functions.ExecuteSql(true, sql)
			
			-- Search the necessary configs
			query.config = {}
            
			query.config.dealership = Config.dealership
            
			query.config.format = Config.format
           
			query.config.repair_value = Config.repair_value
           
			query.config.exp_per_level = Config.exp_per_level
           
			query.config.max_loan_per_level = Config.max_loan_per_level
            
			query.config.loans = Config.loans.values
           
			query.config.cooldown = Config.contracts.cooldown
  
			-- Search for other variables
			query.config.max_loan = getMaxLoan(user_id)
			query.config.player_level = getPlayerLevel(user_id)

			-- Send pro front-end
			TriggerClientEvent("truck_logistics:open",source, query, reset)
		end
	end
end


RegisterServerEvent("truck_logistics:vehicleLock")
AddEventHandler("truck_logistics:vehicleLock",function()
	local source = source
	TriggerClientEvent("truck_logistics:vehicleClientLock",source)
end)


function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

function print_table(node)
    -- to make output beautiful
    local function tab(amt)
        local str = ""
        for i=1,amt do
            str = str .. "\t"
        end
        return str
    end
 
    local cache, stack, output = {},{},{}
    local depth = 1
    local output_str = "{\n"
 
    while true do
        local size = 0
        for k,v in pairs(node) do
            size = size + 1
        end
 
        local cur_index = 1
        for k,v in pairs(node) do
            if (cache[node] == nil) or (cur_index >= cache[node]) then
               
                if (string.find(output_str,"}",output_str:len())) then
                    output_str = output_str .. ",\n"
                elseif not (string.find(output_str,"\n",output_str:len())) then
                    output_str = output_str .. "\n"
                end
 
                -- This is necessary for working with HUGE tables otherwise we run out of memory using concat on huge strings
                table.insert(output,output_str)
                output_str = ""
               
                local key
                if (type(k) == "number" or type(k) == "boolean") then
                    key = "["..tostring(k).."]"
                else
                    key = "['"..tostring(k).."']"
                end
 
                if (type(v) == "number" or type(v) == "boolean") then
                    output_str = output_str .. tab(depth) .. key .. " = "..tostring(v)
                elseif (type(v) == "table") then
                    output_str = output_str .. tab(depth) .. key .. " = {\n"
                    table.insert(stack,node)
                    table.insert(stack,v)
                    cache[node] = cur_index+1
                    break
                else
                    output_str = output_str .. tab(depth) .. key .. " = '"..tostring(v).."'"
                end
 
                if (cur_index == size) then
                    output_str = output_str .. "\n" .. tab(depth-1) .. "}"
                else
                    output_str = output_str .. ","
                end
            else
                -- close the table
                if (cur_index == size) then
                    output_str = output_str .. "\n" .. tab(depth-1) .. "}"
                end
            end
 
            cur_index = cur_index + 1
        end
 
        if (#stack > 0) then
            node = stack[#stack]
            stack[#stack] = nil
            depth = cache[node] == nil and depth + 1 or depth - 1
        else
            break
        end
    end
 
    -- This is necessary for working with HUGE tables otherwise we run out of memory using concat on huge strings
    table.insert(output,output_str)
    output_str = table.concat(output)
   
    print(output_str)
end