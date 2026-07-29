function RegisterJobCallbacks()
	plsr.Callbacks:RegisterServerCallback("Jobs:OnDuty", function(source, jobId, cb)
		cb(plsr.Jobs.Duty:On(source, jobId))
	end)

	plsr.Callbacks:RegisterServerCallback("Jobs:OffDuty", function(source, jobId, cb)
		cb(plsr.Jobs.Duty:Off(source, jobId))
	end)
	plsr.Callbacks:RegisterServerCallback("MetalDetector:Server:Sync", function(source, data, cb)
		TriggerClientEvent("MetalDetector:Client:Sync", -1, data)
		cb(true)
	end)
end
