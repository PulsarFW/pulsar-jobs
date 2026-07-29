local _ranStartup = false
JOB_CACHE = {}
JOB_COUNT = 0

_loaded = false

CreateThread(function()
	RegisterJobMiddleware()
	RegisterJobCallbacks()
	RegisterJobChatCommands()

	_loaded = true

	RunStartup()

	TriggerEvent("Jobs:Server:Startup")
end)

-- `job_id`/`type`/`last_updated` are real columns since they're all queried across rows
-- (default-job version checks, Government/Company aggregation); everything else stays in `data`.
-- `jobs` is fully loaded into JOB_CACHE at boot and after every mutation (RefreshAllJobData), so
-- writes just persist the whole doc and let that refresh rebuild state, same idea as `_properties`.
local _jobsTableReady = false
function EnsureJobsTable(callback)
	if _jobsTableReady then
		if callback then
			callback()
		end
		return
	end
	plsr.Database:Query(
		"CREATE TABLE IF NOT EXISTS `jobs` (`id` BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, `job_id` VARCHAR(191) NOT NULL, `type` VARCHAR(191) NULL, `last_updated` BIGINT NULL, `data` JSON NOT NULL, UNIQUE INDEX `idx_job_id` (`job_id`), INDEX `idx_type` (`type`))",
		nil,
		function()
			_jobsTableReady = true
			if callback then
				callback()
			end
		end
	)
end

function GetJobRow(jobId, callback)
	EnsureJobsTable(function()
		plsr.Database:Single("SELECT `id`, `data` FROM `jobs` WHERE `job_id` = ?", { jobId }, function(success, row)
			if not success or row == nil then
				callback(nil)
				return
			end
			local ok, doc = pcall(json.decode, row.data)
			if not ok or type(doc) ~= "table" then
				callback(nil)
				return
			end
			doc._id = row.id
			callback(doc)
		end)
	end)
end

function PersistJobDoc(doc, callback)
	local toEncode = {}
	for k, v in pairs(doc) do
		toEncode[k] = v
	end
	toEncode._id = nil

	EnsureJobsTable(function()
		plsr.Database:Update(
			"INSERT INTO `jobs` (`job_id`, `type`, `last_updated`, `data`) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE `type` = VALUES(`type`), `last_updated` = VALUES(`last_updated`), `data` = VALUES(`data`)",
			{ toEncode.Id, toEncode.Type, toEncode.LastUpdated, json.encode(toEncode) },
			function(success)
				if callback then
					callback(success)
				end
			end
		)
	end)
end

function FindAllJobs()
	local p = promise.new()

	EnsureJobsTable(function()
		plsr.Database:Query("SELECT `id`, `data` FROM `jobs`", nil, function(success, rows)
			if not success then
				p:resolve({})
				return
			end
			local results = {}
			for k, row in ipairs(rows) do
				local ok, doc = pcall(json.decode, row.data)
				if ok and type(doc) == "table" then
					doc._id = row.id
					table.insert(results, doc)
				end
			end
			p:resolve(results)
		end)
	end)

	local res = Citizen.Await(p)
	return res
end

function RefreshAllJobData(job)
	local jobsFetch = FindAllJobs()
	JOB_COUNT = #jobsFetch
	for k, v in ipairs(jobsFetch) do
		JOB_CACHE[v.Id] = v
	end

	TriggerEvent("Jobs:Server:UpdatedCache", job or -1)

	-- Same info FindAllJobs already pulled; compute the GlobalState perm keys in Lua instead of
	-- a second/third DB round trip via Mongo-style $unwind aggregation.
	for k, v in ipairs(jobsFetch) do
		if v.Type == "Government" and v.Workplaces then
			for _, workplace in ipairs(v.Workplaces) do
				if workplace.Grades then
					for _, grade in ipairs(workplace.Grades) do
						local key = string.format("JobPerms:%s:%s:%s", v.Id, workplace.Id, grade.Id)
						GlobalState[key] = grade.Permissions
					end
				end
			end
		elseif v.Type == "Company" and v.Grades then
			for _, grade in ipairs(v.Grades) do
				local key = string.format("JobPerms:%s:false:%s", v.Id, grade.Id)
				GlobalState[key] = grade.Permissions
			end
		end
	end

	return true
end

function RunStartup()
	if _ranStartup then
		return
	end
	_ranStartup = true

	local function replaceExistingDefaultJob(_id, document)
		local p = promise.new()
		PersistJobDoc(document, function(success)
			if not success then
				plsr.Logger:Error("Jobs", "Error Inserting Job on Default Job Update")
				p:resolve(false)
			else
				Wait(10000)
				p:resolve(true)
			end
		end)
		return p
	end

	local function insertDefaultJob(document)
		local p = promise.new()
		PersistJobDoc(document, function(success)
			if not success then
				plsr.Logger:Error("Jobs", "Error Inserting Job on Default Job Update")
				p:resolve(false)
			else
				p:resolve(true)
			end
		end)
		return p
	end

	local jobsFetch = FindAllJobs()
	local currentData = {}
	for k, v in ipairs(jobsFetch) do
		currentData[v.Id] = v
	end

	local awaitingPromises = {}
	for k, v in ipairs(_defaultJobData) do
		local currentDataForJob = currentData[v.Id]
		if currentDataForJob and currentDataForJob.LastUpdated < v.LastUpdated then
			table.insert(awaitingPromises, replaceExistingDefaultJob(currentDataForJob._id, v))
		elseif not currentDataForJob then
			table.insert(awaitingPromises, insertDefaultJob(v))
		end
	end

	if #awaitingPromises > 0 then
		Citizen.Await(promise.all(awaitingPromises))
		plsr.Logger:Info("Jobs", "Inserted/Replaced ^2" .. #awaitingPromises .. "^7 Default Jobs")
		jobsFetch = FindAllJobs()
	end

	RefreshAllJobData()
	plsr.Logger:Trace("Jobs", string.format("Loaded ^2%s^7 Jobs", JOB_COUNT))
	TriggerEvent("Jobs:Server:CompleteStartup")
end
