_characterDuty = {}
_dutyData = {}

_JOBS = {
	GetAll = function(self)
		return JOB_CACHE
	end,
	Get = function(self, jobId)
		return JOB_CACHE[jobId]
	end,
	DoesExist = function(self, jobId, workplaceId, gradeId)
		local job = plsr.Jobs:Get(jobId)
		if job then
			if workplaceId and job.Workplaces then
				for _, workplace in ipairs(job.Workplaces) do
					if workplace.Id == workplaceId then
						if not gradeId then
							return {
								Id = job.Id,
								Name = job.Name,
								Workplace = false,
								Hidden = job.Hidden,
							}
						end

						for _, grade in ipairs(workplace.Grades) do
							if grade.Id == gradeId then
								return {
									Id = job.Id,
									Name = job.Name,
									Workplace = {
										Id = workplace.Id,
										Name = workplace.Name,
									},
									Grade = {
										Id = grade.Id,
										Name = grade.Name,
										Level = grade.Level,
										Permissions = grade.Permissions,
									},
									Hidden = job.Hidden,
								}
							end
						end
					end
				end
			elseif not workplaceId then
				if not gradeId then
					return {
						Id = job.Id,
						Name = job.Name,
						Workplace = false,
						Hidden = job.Hidden,
					}
				elseif gradeId and job.Grades then
					for _, grade in ipairs(job.Grades) do
						if grade.Id == gradeId then
							return {
								Id = job.Id,
								Name = job.Name,
								Workplace = false,
								Grade = {
									Id = grade.Id,
									Name = grade.Name,
									Level = grade.Level,
									Permissions = grade.Permissions,
								},
								Hidden = job.Hidden,
							}
						end
					end
				end
			end
		end
		return false
	end,
	GiveJob = function(self, stateId, jobId, workplaceId, gradeId, noOverride)
		local newJob = plsr.Jobs:DoesExist(jobId, workplaceId, gradeId)
		if not newJob or not newJob.Grade then
			return false
		end

		local char = plsr.Fetch:SID(stateId)

		if char then
			local charJobData = char:GetData("Jobs")
			if not charJobData then
				charJobData = {}
			end

			for k, v in ipairs(charJobData) do
				if v.Id == newJob.Id then
					if noOverride then
						return false
					else
						table.remove(charJobData, k)
					end
				end
			end

			table.insert(charJobData, newJob)

			local source = char:GetData("Source")
			char:SetData("Jobs", charJobData)

			plsr.Middleware:TriggerEvent("Characters:ForceStore", source)

			plsr.Phone:UpdateJobData(source)

			TriggerEvent("Jobs:Server:JobUpdate", source)

			return true
		else
			local p = promise.new()
			plsr.Database:Single("SELECT `data` FROM `characters` WHERE `sid` = ? AND `deleted` = 0", { stateId }, function(success, row)
				if not success or row == nil then
					p:resolve(false)
					return
				end
				local ok, charData = pcall(json.decode, row.data)
				if not ok or type(charData) ~= "table" then
					p:resolve(false)
					return
				end
				local charJobData = charData.Jobs or {}

				for k, v in ipairs(charJobData) do
					if v.Id == newJob.Id then
						if noOverride then
							p:resolve(false)
							return
						else
							table.remove(charJobData, k)
						end
					end
				end

				table.insert(charJobData, newJob)

				plsr.Database:Update(
					"UPDATE `characters` SET `data` = JSON_SET(`data`, '$.Jobs', CAST(? AS JSON)) WHERE `sid` = ?",
					{ json.encode(charJobData), stateId },
					function(updateSuccess)
						p:resolve(updateSuccess)
					end
				)
			end)

			local res = Citizen.Await(p)
			return res
		end
	end,
	RemoveJob = function(self, stateId, jobId)
		local char = plsr.Fetch:SID(stateId)

		if char then
			local found = false
			local charJobData = char:GetData("Jobs")
			if not charJobData then
				charJobData = {}
			end
			local removedJobData

			for k, v in ipairs(charJobData) do
				if v.Id == jobId then
					removedJobData = v
					found = true
					table.remove(charJobData, k)
				end
			end

			if found then
				local source = char:GetData("Source")
				char:SetData("Jobs", charJobData)
				plsr.Jobs.Duty:Off(source, jobId, true)

				plsr.Middleware:TriggerEvent("Characters:ForceStore", source)
				plsr.Phone:UpdateJobData(source)
				TriggerEvent("Jobs:Server:JobUpdate", source)

				if removedJobData.Workplace and removedJobData.Workplace.Name then
					plsr.Execute:Client(
						source,
						"Notification",
						"Info",
						"No Longer Employed at " .. removedJobData.Workplace.Name
					)
				else
					plsr.Execute:Client(source, "Notification", "Info", "No Longer Employed at " .. removedJobData.Name)
				end

				return true
			end
		else
			local p = promise.new()
			plsr.Database:Single("SELECT `data` FROM `characters` WHERE `sid` = ? AND `deleted` = 0", { stateId }, function(success, row)
				if not success or row == nil then
					p:resolve(false)
					return
				end
				local ok, charData = pcall(json.decode, row.data)
				if not ok or type(charData) ~= "table" then
					p:resolve(false)
					return
				end
				local charJobData = charData.Jobs
				if charJobData then
					for k, v in ipairs(charJobData) do
						if v.Id == jobId then
							found = true
							table.remove(charJobData, k)
						end
					end

					if found then
						plsr.Database:Update(
							"UPDATE `characters` SET `data` = JSON_SET(`data`, '$.Jobs', CAST(? AS JSON)) WHERE `sid` = ?",
							{ json.encode(charJobData), stateId },
							function(updateSuccess)
								p:resolve(updateSuccess)
							end
						)
					else
						p:resolve(false)
					end
				else
					p:resolve(false)
				end
			end)

			local res = Citizen.Await(p)
			return res
		end
	end,
	Duty = {
		On = function(self, source, jobId, hideNotify)
			local char = plsr.Fetch:CharacterSource(source)
			if char then
				local stateId = char:GetData("SID")
				local charJobs = char:GetData("Jobs")
				local hasJob = false

				for k, v in ipairs(charJobs) do
					if v.Id == jobId then
						hasJob = v
						break
					end
				end

				if hasJob then
					local dutyData = _characterDuty[stateId]
					if dutyData then
						if dutyData.Id == hasJob.Id then
							return true -- Already on duty as that job
						else
							local success = plsr.Jobs.Duty:Off(source, false, true)
							if not success then
								return false
							end
						end
					end

					_characterDuty[stateId] = {
						Source = source,
						Id = hasJob.Id,
						StartTime = os.time(),
						Time = os.time(),
						WorkplaceId = (hasJob.Workplace and hasJob.Workplace.Id or false),
						GradeId = hasJob.Grade.Id,
						GradeLevel = hasJob.Grade.Level,
						First = char:GetData("First"),
						Last = char:GetData("Last"),
						Callsign = char:GetData("Callsign"),
					}

					plsr.State:SetPublicFlag(source, 'onDuty', _characterDuty[stateId].Id)

					local callsign = char:GetData("Callsign")
					TriggerEvent("Job:Server:DutyAdd", _characterDuty[stateId], source, stateId, callsign)
					TriggerClientEvent("Job:Client:DutyChanged", source, _characterDuty[stateId].Id)
					plsr.Jobs.Duty:RefreshDutyData(hasJob.Id)

					local lastOnDutyData = char:GetData("LastClockOn") or {}
					lastOnDutyData[hasJob.Id] = os.time()
					char:SetData("LastClockOn", lastOnDutyData)

					if not hideNotify then
						if hasJob.Workplace then
							plsr.Execute:Client(
								source,
								"Notification",
								"Success",
								string.format(
									"You're Now On Duty as %s - %s",
									hasJob.Workplace.Name,
									hasJob.Grade.Name
								)
							)
						else
							plsr.Execute:Client(
								source,
								"Notification",
								"Success",
								string.format("You're Now On Duty as %s - %s", hasJob.Name, hasJob.Grade.Name)
							)
						end
					end

					return hasJob
				end
			end

			if not hideNotify then
				plsr.Execute:Client(source, "Notification", "Error", "Failed to Go On Duty")
			end

			return false
		end,
		Off = function(self, source, jobId, hideNotify)
			local char = plsr.Fetch:CharacterSource(source)
			if char then
				local stateId = char:GetData("SID")
				local dutyData = _characterDuty[stateId]
				if dutyData and (not jobId or (dutyData.Id == jobId)) then
					local dutyId = dutyData.Id
					plsr.State:SetPublicFlag(source, 'onDuty', false)

					local existing = char:GetData("Salary") or {}
					local workedMinutes = math.floor((os.time() - dutyData.Time) / 60)
					local j = plsr.Jobs:Get(dutyData.Id)
					local salary = math.ceil((j.Salary * j.SalaryTier) * (workedMinutes / _payPeriod))

					plsr.Logger:Info(
						"Jobs",
						string.format(
							"Adding Salary Data For ^3%s^7 Going Off-Duty (^2%s Minutes^7 - ^3$%s^7)",
							char:GetData("SID"),
							workedMinutes,
							salary
						)
					)

					if existing[dutyData.Id] then
						existing[dutyData.Id] = {
							date = os.time(),
							job = dutyData.Id,
							minutes = (existing[dutyData.Id].minutes or 0) + workedMinutes,
							total = (existing[dutyData.Id].total or 0) + salary,
						}
					else
						existing[dutyData.Id] = {
							date = os.time(),
							job = dutyData.Id,
							minutes = workedMinutes,
							total = salary,
						}
					end

					char:SetData("Salary", existing)

					TriggerEvent("Job:Server:DutyRemove", dutyData, source, stateId)
					TriggerClientEvent("Job:Client:DutyChanged", source, false, dutyData.Id)
					_characterDuty[stateId] = nil
					plsr.Jobs.Duty:RefreshDutyData(dutyId)

					local totalWorkedMinutes = math.floor((os.time() - dutyData.StartTime) / 60)
					local allTimeWorked = char:GetData("TimeClockedOn") or {}
					local jobTimeWorked = allTimeWorked[dutyData.Id] or {}

					if totalWorkedMinutes and totalWorkedMinutes >= 5 then
						table.insert(jobTimeWorked, {
							time = os.time(),
							minutes = totalWorkedMinutes,
						})

						local deleteBefore = os.time() - (60 * 60 * 24 * 14) -- Only Keep Last 14 Days
						for k, v in ipairs(jobTimeWorked) do
							if tonumber(v.time) < deleteBefore then
								table.remove(jobTimeWorked, k)
							end
						end

						allTimeWorked[dutyData.Id] = jobTimeWorked
					end
					char:SetData("TimeClockedOn", allTimeWorked)

					if not hideNotify then
						plsr.Execute:Client(source, "Notification", "Info", "You're Now Off Duty")
					end

					return true
				end
			end

			if not hideNotify then
				plsr.Execute:Client(source, "Notification", "Error", "Failed to Go Off Duty")
			end

			return false
		end,
		Get = function(self, source, jobId)
			local char = plsr.Fetch:CharacterSource(source)
			if char then
				local dutyData = _characterDuty[char:GetData("SID")]
				if dutyData and (not jobId or (jobId == dutyData.Id)) then
					return dutyData
				end
			end
			return false
		end,
		GetDutyData = function(self, jobId)
			return _dutyData[jobId]
		end,
		RefreshDutyData = function(self, jobId)
			if not _dutyData[jobId] then
				_dutyData[jobId] = {}
			end

			local onDutyPlayers = {}
			local totalCount = 0
			local workplaceCounts = false

			for k, v in pairs(_characterDuty) do
				if v ~= nil and v.Id == jobId then
					totalCount = totalCount + 1
					table.insert(onDutyPlayers, v.Source)
					if v.WorkplaceId then
						if not workplaceCounts then
							workplaceCounts = {}
						end

						if not workplaceCounts[v.WorkplaceId] then
							workplaceCounts[v.WorkplaceId] = 1
						else
							workplaceCounts[v.WorkplaceId] = workplaceCounts[v.WorkplaceId] + 1
						end
					end
				end
			end

			_dutyData[jobId] = {
				Active = totalCount > 0,
				Count = totalCount,
				WorkplaceCounts = workplaceCounts,
				DutyPlayers = onDutyPlayers,
			}

			if _globalStateDutyCounts and _globalStateDutyCounts[jobId] then
				GlobalState[string.format("Duty:%s", jobId)] = totalCount
			end
		end,
	},
	Permissions = {
		IsOwner = function(self, source, jobId)
			local char = plsr.Fetch:CharacterSource(source)
			if char then
				local jobData = plsr.Jobs:Get(jobId)
				-- Owner comes back from the jobs table's JSON blob, which doesn't preserve number vs string reliably - compare as strings
				if jobData.Owner and tostring(jobData.Owner) == tostring(char:GetData("SID")) then
					return true
				end
			end
			return false
		end,
		IsOwnerOfCompany = function(self, source)
			local char = plsr.Fetch:CharacterSource(source)
			if char then
				local stateId = char:GetData("SID")
				local jobs = char:GetData("Jobs") or {}
				for k, v in ipairs(jobs) do
					local jobData = plsr.Jobs:Get(v.Id)
					if jobData.Owner and tostring(jobData.Owner) == tostring(stateId) then
						return true
					end
				end
			end
			return false
		end,
		GetJobs = function(self, source)
			local char = plsr.Fetch:CharacterSource(source)
			if char then
				local jobs = char:GetData("Jobs") or {}
				return jobs
			end
			return false
		end,
		HasJob = function(self, source, jobId, workplaceId, gradeId, gradeLevel, checkDuty, permissionKey)
			local jobs = plsr.Jobs.Permissions:GetJobs(source)
			if not jobs then
				return false
			end
			if jobId then
				for k, v in ipairs(jobs) do
					if v.Id == jobId then
						if not workplaceId or (v.Workplace and v.Workplace.Id == workplaceId) then
							if not gradeId or (v.Grade.Id == gradeId) then
								if not gradeLevel or (v.Grade.Level and v.Grade.Level >= gradeLevel) then
									if not checkDuty or (checkDuty and plsr.Jobs.Duty:Get(source, jobId)) then
										if
											not permissionKey
											or (
												permissionKey
												and plsr.Jobs.Permissions:HasPermissionInJob(source, jobId, permissionKey)
											)
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
			elseif permissionKey then
				return plsr.Jobs.Permissions:HasPermission(source, permissionKey)
			end
			return false
		end,
		-- Gets the permissions the character has in a job they have
		GetPermissionsFromJob = function(self, source, jobId, workplaceId)
			local jobData = plsr.Jobs.Permissions:HasJob(source, jobId, workplaceId)
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
		HasPermissionInJob = function(self, source, jobId, permissionKey)
			local permissionsInJob = plsr.Jobs.Permissions:GetPermissionsFromJob(source, jobId)
			if permissionsInJob then
				if permissionsInJob[permissionKey] then
					return true
				end
			end
			return false
		end,
		-- Gets permissions from all jobs
		GetAllPermissions = function(self, source)
			local allPermissions = {}
			local jobs = plsr.Jobs.Permissions:GetJobs(source)
			if jobs and #jobs > 0 then
				for k, v in ipairs(jobs) do
					local perms = GlobalState[string.format(
						"JobPerms:%s:%s:%s",
						v.Id,
						(v.Workplace and v.Workplace.Id or false),
						v.Grade.Id
					)]
					if perms ~= nil then
						for k, v in pairs(perms) do
							if not allPermissions[k] then
								allPermissions[k] = v
							end
						end
					end
				end
			end
			return allPermissions
		end,
		-- Checks if character has a permission in any of their jobs
		HasPermission = function(self, source, permissionKey)
			local allPermissions = plsr.Jobs.Permissions:GetAllPermissions(source)
			return allPermissions[permissionKey]
		end,
	},
	Management = {
		Create = function(self, name, ownerSID) -- For player business creations
			if not name then
				name = plsr.Generator:Company()
			end
			local jobId = string.format("Company_%s", plsr.Sequence:Get("Company"))
			if jobId and name then
				local existing = plsr.Jobs:Get(jobId)
				if not existing then
					local p = promise.new()
					local document = {
						Type = "Company",
						Custom = true,
						Id = jobId,
						Name = name,
						Owner = ownerSID,
						Salary = 100,
						SalaryTier = 1,
						Grades = {
							{
								Id = "owner",
								Name = "Owner",
								Level = 100,
								Permissions = {
									JOB_MANAGEMENT = true,
									JOB_FIRE = true,
									JOB_HIRE = true,
									JOB_MANAGE_EMPLOYEES = true,
								},
							},
						},
					}

					PersistJobDoc(document, function(success)
						if success then
							RefreshAllJobData(document.Id)

							plsr.Jobs:GiveJob(ownerSID, document.Id, false, "owner")

							p:resolve(document)
						else
							p:resolve(false)
						end
					end)

					local res = Citizen.Await(p)
					return res
				end
			end
			return false
		end,
		Transfer = function(self, jobId, newOwner)
			-- TODO
			--plsr.Middleware:TriggerEvent("Business:Transfer", jobId, source:GetData("SID"), target:GetData("SID"))
		end,
		Upgrades = {
			-- TODO
			Has = function(self, jobId, upgradeKey) end,
			Unlock = function(self, jobId, upgradeKey) end,
			Lock = function(self, jobId, upgradeKey) end,
			Reset = function(self, jobId) end,
		},
		Delete = function(self, jobId)
			-- TODO
		end,
		Edit = function(self, jobId, settingData)
			if plsr.Jobs:DoesExist(jobId) then
				local actualSettingData = {}

				for k, v in pairs(settingData) do
					if k ~= "Grades" and k ~= "Workplaces" and k ~= "Id" and v ~= nil then
						actualSettingData[k] = v
					end
				end

				local p = promise.new()
				GetJobRow(jobId, function(doc)
					if not doc then
						p:resolve(false)
						return
					end
					for k, v in pairs(actualSettingData) do
						doc[k] = v
					end

					PersistJobDoc(doc, function(success)
						if success then
							RefreshAllJobData(jobId)

							if actualSettingData.Name then
								plsr.Jobs.Management.Employees:UpdateAllJob(jobId, actualSettingData.Name)
							end

							p:resolve(true)
						else
							p:resolve(false)
						end
					end)
				end)

				local res = Citizen.Await(p)
				return {
					success = res,
					code = "ERROR",
				}
			else
				return {
					success = false,
					code = "MISSING_JOB",
				}
			end
		end,
		Workplace = {
			Edit = function(self, jobId, workplaceId, newWorkplaceName)
				if plsr.Jobs:DoesExist(jobId, workplaceId) then
					local p = promise.new()
					GetJobRow(jobId, function(doc)
						local workplace = nil
						if doc and doc.Workplaces then
							for _, w in ipairs(doc.Workplaces) do
								if w.Id == workplaceId then
									workplace = w
									break
								end
							end
						end
						if not workplace then
							p:resolve(false)
							return
						end
						workplace.Name = newWorkplaceName

						PersistJobDoc(doc, function(success)
							if success then
								RefreshAllJobData(jobId)
								plsr.Jobs.Management.Employees:UpdateAllWorkplace(jobId, workplaceId, newWorkplaceName)

								p:resolve(true)
							else
								p:resolve(false)
							end
						end)
					end)

					local res = Citizen.Await(p)
					return {
						success = res,
						code = "ERROR",
					}
				else
					return {
						success = false,
						code = "ERROR",
					}
				end
			end,
		},
		Grades = {
			Create = function(self, jobId, workplaceId, gradeName, gradeLevel, gradePermissions)
				if plsr.Jobs:DoesExist(jobId, workplaceId) then
					local p = promise.new()
					local gradeId
					if workplaceId then
						gradeId = string.format(
							"Grade_%s",
							plsr.Sequence:Get(string.format("Company:%s:%s:Grades", jobId, workplaceId))
						)
					else
						gradeId = string.format("Grade_%s", plsr.Sequence:Get(string.format("Company:%s:Grades", jobId)))
					end

					if not plsr.Jobs:DoesExist(jobId, workplaceId, gradeId) then
						local gradeData = {
							Id = gradeId,
							Name = gradeName,
							Level = gradeLevel,
							Permissions = gradePermissions or {},
						}

						GetJobRow(jobId, function(doc)
							if not doc then
								p:resolve(false)
								return
							end

							local target = nil
							if workplaceId then
								if doc.Workplaces then
									for _, w in ipairs(doc.Workplaces) do
										if w.Id == workplaceId then
											if not w.Grades then
												w.Grades = {}
											end
											target = w.Grades
											break
										end
									end
								end
							else
								if not doc.Grades then
									doc.Grades = {}
								end
								target = doc.Grades
							end

							if not target then
								p:resolve(false)
								return
							end
							table.insert(target, gradeData)

							PersistJobDoc(doc, function(success)
								if success then
									RefreshAllJobData(jobId)

									p:resolve(true)
								else
									p:resolve(false)
								end
							end)
						end)

						local res = Citizen.Await(p)
						return {
							success = res,
							code = "ERROR",
						}
					else
						return {
							success = false,
							code = "ERROR",
						}
					end
				else
					return {
						success = false,
						code = "MISSING_JOB",
					}
				end
			end,
			Edit = function(self, jobId, workplaceId, gradeId, settingData)
				if plsr.Jobs:DoesExist(jobId, workplaceId, gradeId) then
					local p = promise.new()

					GetJobRow(jobId, function(doc)
						if not doc then
							p:resolve(false)
							return
						end

						local grade = nil
						if workplaceId then
							if doc.Workplaces then
								for _, w in ipairs(doc.Workplaces) do
									if w.Id == workplaceId and w.Grades then
										for _, g in ipairs(w.Grades) do
											if g.Id == gradeId then
												grade = g
												break
											end
										end
									end
									if grade then
										break
									end
								end
							end
						else
							if doc.Grades then
								for _, g in ipairs(doc.Grades) do
									if g.Id == gradeId then
										grade = g
										break
									end
								end
							end
						end

						if not grade then
							p:resolve(false)
							return
						end

						for k, v in pairs(settingData) do
							if k ~= "Id" then
								grade[k] = v
							end
						end

						PersistJobDoc(doc, function(success)
							if success then
								RefreshAllJobData(jobId)
								plsr.Jobs.Management.Employees:UpdateAllGrade(jobId, workplaceId, gradeId, settingData)

								p:resolve(true)
							else
								p:resolve(false)
							end
						end)
					end)

					local res = Citizen.Await(p)
					return {
						success = res,
						code = "ERROR",
					}
				else
					return {
						success = false,
						code = "MISSING_JOB",
					}
				end
			end,
			Delete = function(self, jobId, workplaceId, gradeId)
				local peopleWithJobGrade = plsr.Jobs.Management.Employees:GetAll(jobId, workplaceId, gradeId)
				if #peopleWithJobGrade <= 0 then
					if plsr.Jobs:DoesExist(jobId, workplaceId, gradeId) then
						local p = promise.new()
						GetJobRow(jobId, function(doc)
							if not doc then
								p:resolve(false)
								return
							end

							if workplaceId then
								if doc.Workplaces then
									for _, w in ipairs(doc.Workplaces) do
										if w.Id == workplaceId and w.Grades then
											for k, g in ipairs(w.Grades) do
												if g.Id == gradeId then
													table.remove(w.Grades, k)
													break
												end
											end
										end
									end
								end
							else
								if doc.Grades then
									for k, g in ipairs(doc.Grades) do
										if g.Id == gradeId then
											table.remove(doc.Grades, k)
											break
										end
									end
								end
							end

							PersistJobDoc(doc, function(success)
								if success then
									RefreshAllJobData(jobId)

									p:resolve(true)
								else
									p:resolve(false)
								end
							end)
						end)

						local res = Citizen.Await(p)
						return {
							success = res,
							code = "ERROR",
						}
					else
						return {
							success = false,
							code = "MISSING_JOB",
						}
					end
				else
					return {
						success = false,
						code = "JOB_OCCUPIED",
					}
				end
			end,
		},
		Employees = {
			GetAll = function(self, jobId, workplaceId, gradeId)
				local jobCharacters = {}
				local onlineCharacters = {}
				for k, v in pairs(plsr.Fetch:AllCharacters()) do
					if v ~= nil then
						table.insert(onlineCharacters, v:GetData("SID"))
						local jobs = v:GetData("Jobs")
						if jobs and #jobs > 0 then
							for k, v in ipairs(jobs) do
								if
									v.Id == jobId
									and (not workplaceId or (workplaceId and (v.Workplace and v.Workplace.Id == workplaceId)))
									and (not gradeId or (v.Grade.Id == gradeId))
								then
									table.insert(jobCharacters, {
										Source = v:GetData("Source"),
										SID = v:GetData("SID"),
										First = v:GetData("First"),
										Last = v:GetData("Last"),
										Phone = v:GetData("Phone"),
										JobData = v,
									})
								end
							end
						end
					end
				end

				local p = promise.new()

				local placeholders = {}
				for i = 1, #onlineCharacters do
					table.insert(placeholders, "?")
				end
				local excludeClause = #onlineCharacters > 0 and (" AND `sid` NOT IN (" .. table.concat(placeholders, ", ") .. ")") or ""

				plsr.Database:Query(
					"SELECT `data` FROM `characters` WHERE `deleted` = 0" .. excludeClause,
					onlineCharacters,
					function(success, rows)
						if success then
							for _, row in ipairs(rows) do
								local ok, c = pcall(json.decode, row.data)
								if ok and type(c) == "table" and c.Jobs and #c.Jobs > 0 then
									for k, v in ipairs(c.Jobs) do
										if
											v.Id == jobId
											and (not workplaceId or (workplaceId and (v.Workplace and v.Workplace.Id == workplaceId)))
											and (not gradeId or (v.Grade.Id == gradeId))
										then
											table.insert(jobCharacters, {
												Source = false,
												SID = c.SID,
												First = c.First,
												Last = c.Last,
												Phone = c.Phone,
												JobData = v,
											})
										end
									end
								end
							end
							p:resolve(true)
						else
							p:resolve(false)
						end
					end
				)

				local res = Citizen.Await(p)
				if res then
					return jobCharacters
				else
					return false
				end
			end,
			UpdateAllJob = function(self, jobId, newJobName)
				local onlineCharacters = {}
				for k, v in pairs(plsr.Fetch:AllCharacters()) do
					if v ~= nil then
						table.insert(onlineCharacters, v:GetData("SID"))
						local jobs = v:GetData("Jobs")
						if jobs and #jobs > 0 then
							for k, v in ipairs(jobs) do
								if v.Id == jobId then
									v.Name = newJobName
									v:SetData("Jobs", jobs)
									plsr.Phone:UpdateJobData(v:GetData("Source"))
								end
							end
						end
					end
				end

				local p = promise.new()

				local placeholders = {}
				for i = 1, #onlineCharacters do
					table.insert(placeholders, "?")
				end
				local excludeClause = #onlineCharacters > 0 and (" AND `sid` NOT IN (" .. table.concat(placeholders, ", ") .. ")") or ""

				plsr.Database:Query(
					"SELECT `id`, `data` FROM `characters` WHERE `deleted` = 0" .. excludeClause,
					onlineCharacters,
					function(success, rows)
						if not success then
							p:resolve(false)
							return
						end

						local updated = 0
						for _, row in ipairs(rows) do
							local ok, c = pcall(json.decode, row.data)
							if ok and type(c) == "table" and c.Jobs then
								local changed = false
								for k, v in ipairs(c.Jobs) do
									if v.Id == jobId then
										v.Name = newJobName
										changed = true
									end
								end
								if changed then
									plsr.Database:Update("UPDATE `characters` SET `data` = JSON_SET(`data`, '$.Jobs', CAST(? AS JSON)) WHERE `id` = ?", { json.encode(c.Jobs), row.id })
									updated = updated + 1
								end
							end
						end
						p:resolve(updated)
					end
				)

				local res = Citizen.Await(p)
				return res
			end,
			UpdateAllWorkplace = function(self, jobId, workplaceId, newWorkplaceName)
				local p = promise.new()

				local jobCharacters = {}
				local onlineCharacters = {}
				for k, v in pairs(plsr.Fetch:AllCharacters()) do
					if v ~= nil then
						table.insert(onlineCharacters, v:GetData("SID"))
						local jobs = v:GetData("Jobs")
						if jobs and #jobs > 0 then
							for k, v in ipairs(jobs) do
								if v.Id == jobId and (v.Workplace and (v.Workplace.Id == workplaceId)) then
									v.Workplace.Name = newWorkplaceName
									v:SetData("Jobs", jobs)
									plsr.Phone:UpdateJobData(v:GetData("Source"))
								end
							end
						end
					end
				end

				local placeholders = {}
				for i = 1, #onlineCharacters do
					table.insert(placeholders, "?")
				end
				local excludeClause = #onlineCharacters > 0 and (" AND `sid` NOT IN (" .. table.concat(placeholders, ", ") .. ")") or ""

				plsr.Database:Query(
					"SELECT `id`, `data` FROM `characters` WHERE `deleted` = 0" .. excludeClause,
					onlineCharacters,
					function(success, rows)
						if not success then
							p:resolve(false)
							return
						end

						local updated = 0
						for _, row in ipairs(rows) do
							local ok, c = pcall(json.decode, row.data)
							if ok and type(c) == "table" and c.Jobs then
								local changed = false
								for k, v in ipairs(c.Jobs) do
									if v.Id == jobId and v.Workplace and v.Workplace.Id == workplaceId then
										v.Workplace.Name = newWorkplaceName
										changed = true
									end
								end
								if changed then
									plsr.Database:Update("UPDATE `characters` SET `data` = JSON_SET(`data`, '$.Jobs', CAST(? AS JSON)) WHERE `id` = ?", { json.encode(c.Jobs), row.id })
									updated = updated + 1
								end
							end
						end
						p:resolve(updated)
					end
				)

				local res = Citizen.Await(p)
				return res
			end,
			UpdateAllGrade = function(self, jobId, workplaceId, gradeId, settingData)
				local jobCharacters = {}
				local onlineCharacters = {}

				if settingData.Name or settingData.Level then
					local p = promise.new()
					for k, v in pairs(plsr.Fetch:AllCharacters()) do
						if v ~= nil then
							table.insert(onlineCharacters, v:GetData("SID"))
							local jobs = v:GetData("Jobs")
							if jobs and #jobs > 0 then
								for k2, v2 in ipairs(jobs) do
									if
										v2.Id == jobId
										and (not workplaceId or (workplaceId and v2.Workplace and (v2.Workplace.Id == workplaceId)))
										and v2.Grade.Id == gradeId
									then
										if settingData.Name then
											v2.Grade.Name = settingData.Name
										end

										if settingData.Level then
											v2.Grade.Level = settingData.Level
										end

										v:SetData("Jobs", jobs)
										plsr.Phone:UpdateJobData(v:GetData("Source"))
									end
								end
							end
						end
					end

					local placeholders = {}
					for i = 1, #onlineCharacters do
						table.insert(placeholders, "?")
					end
					local excludeClause = #onlineCharacters > 0 and (" AND `sid` NOT IN (" .. table.concat(placeholders, ", ") .. ")") or ""

					plsr.Database:Query(
						"SELECT `id`, `data` FROM `characters` WHERE `deleted` = 0" .. excludeClause,
						onlineCharacters,
						function(success, rows)
							if not success then
								p:resolve(false)
								return
							end

							local updated = 0
							for _, row in ipairs(rows) do
								local ok, c = pcall(json.decode, row.data)
								if ok and type(c) == "table" and c.Jobs then
									local changed = false
									for k2, v2 in ipairs(c.Jobs) do
										if
											v2.Id == jobId
											and (not workplaceId or (v2.Workplace and v2.Workplace.Id == workplaceId))
											and v2.Grade.Id == gradeId
										then
											if settingData.Name then
												v2.Grade.Name = settingData.Name
											end
											if settingData.Level then
												v2.Grade.Level = settingData.Level
											end
											changed = true
										end
									end
									if changed then
										plsr.Database:Update("UPDATE `characters` SET `data` = JSON_SET(`data`, '$.Jobs', CAST(? AS JSON)) WHERE `id` = ?", { json.encode(c.Jobs), row.id })
										updated = updated + 1
									end
								end
							end
							p:resolve(updated)
						end
					)

					local res = Citizen.Await(p)
					return res
				end
			end,
		},
	},
	Data = {
		Set = function(self, jobId, key, val)
			if plsr.Jobs:DoesExist(jobId) and key then
				local p = promise.new()
				GetJobRow(jobId, function(doc)
					if not doc then
						p:resolve(false)
						return
					end
					if not doc.Data then
						doc.Data = {}
					end
					doc.Data[key] = val

					PersistJobDoc(doc, function(success)
						if success then
							RefreshAllJobData(jobId)

							p:resolve(true)
						else
							p:resolve(false)
						end
					end)
				end)

				local res = Citizen.Await(p)
				return {
					success = res,
					code = "ERROR",
				}
			else
				return {
					success = false,
					code = "MISSING_JOB",
				}
			end
		end,
		Get = function(self, jobId, key)
			if key and JOB_CACHE[jobId] and JOB_CACHE[jobId].Data then
				return JOB_CACHE[jobId].Data[key]
			end
		end,
	},
}

AddEventHandler("Proxy:Shared:RegisterReady", function()
	exports["pulsar_core"]:RegisterComponent("Jobs", _JOBS)
end)
