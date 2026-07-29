_JOBS = {
	Permissions = {
		GetJobs = function(self)
			if plsr.State.flags.loggedIn then
				local jobs = plsr.State.character.Jobs or {}
				return jobs
			end
			return false
		end,
		HasJob = function(self, jobId, workplaceId, gradeId, gradeLevel, checkDuty, permissionKey)
			local jobs = plsr.Jobs.Permissions:GetJobs()
			for k, v in ipairs(jobs) do
				if v.Id == jobId then
					if not workplaceId or (v.Workplace and v.Workplace.Id == workplaceId) then
						if not gradeId or (v.Grade.Id == gradeId) then
							if not gradeLevel or (v.Grade.Level and v.Grade.Level >= gradeLevel) then
								if not checkDuty or (checkDuty and plsr.Jobs.Duty:Get(jobId)) then
									if
										not permissionKey
										or (permissionKey and plsr.Jobs.Permissions:HasPermissionInJob(jobId, permissionKey))
									then
										return v
									end
								end
							end
						end
					end
					break
				end
			end
			return false
		end,
		-- Gets the permissions the character has in a job they have
		GetPermissionsFromJob = function(self, jobId, workplaceId)
			local jobData = plsr.Jobs.Permissions:HasJob(jobId, workplaceId)
			if jobData then
				local perms = GlobalState[string.format(
					"JobPerms:%s:%s:%s",
					jobData.Id,
					(jobData.Workplace and jobData.Workplace.Id or false),
					jobData.Grade.Id
				)]
				if perms then
					return perms
				end
			end
			return false
		end,
		-- Checks if character has a permission in a specific job they have
		HasPermissionInJob = function(self, jobId, permissionKey)
			local permissionsInJob = plsr.Jobs.Permissions:GetPermissionsFromJob(jobId)
			if permissionsInJob then
				if permissionsInJob[permissionKey] then
					return true
				end
			end
			return false
		end,
		-- Checks if character has a permission in any of their jobs
		HasPermission = function(self, permissionKey)
			local jobs = plsr.Jobs.Permissions:GetJobs()
			if jobs then
				for k, v in ipairs(jobs) do
					if plsr.Jobs.Permissions:HasPermissionInJob(v.Id, permissionKey) then
						return true
					end
				end
			end
			return false
		end,
	},
	Duty = {
		On = function(self, jobId, cb)
			if jobId then
				if plsr.Jobs.Duty:Get(jobId) then
					plsr.Notification:Error("Already On Duty as that Job")
					if cb then
						cb(false)
					end
					return
				end
			end

			plsr.Callbacks:ServerCallback("Jobs:OnDuty", jobId, function(success)
				if cb then
					cb(success)
				end
			end)
		end,
		Off = function(self, jobId, cb)
			plsr.Callbacks:ServerCallback("Jobs:OffDuty", jobId, function(success)
				if cb then
					cb(success)
				end
			end)
		end,
		Get = function(self, jobId)
			local onDuty = plsr.State.flags.onDuty
			if onDuty then
				if (not jobId) or (jobId == onDuty) then
					return onDuty
				end
			end
			return false
		end,
	},
}

AddEventHandler("Proxy:Shared:RegisterReady", function()
	exports["pulsar_core"]:RegisterComponent("Jobs", _JOBS)
end)
