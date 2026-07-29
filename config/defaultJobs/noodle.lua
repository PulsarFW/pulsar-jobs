table.insert(_defaultJobData, {
	Type = "Company",
	LastUpdated = 1784524361,
	Id = "noodle",
	Name = "Noodle Exchange",
	Salary = 600,
	SalaryTier = 1,
	Grades = {
		{
			Id = "cashier",
			Name = "Cashier",
			Level = 1,
			Permissions = {
				JOB_STORAGE = true,
			},
		},
		{
			Id = "chef",
			Name = "Chef",
			Level = 2,
			Permissions = {
				JOB_STORAGE = true,
				JOB_CRAFTING = true,
			},
		},
		{
			Id = "schef",
			Name = "Senior Chef",
			Level = 3,
			Permissions = {
				JOB_STORAGE = true,
				JOB_CRAFTING = true,
			},
		},
		{
			Id = "manager",
			Name = "Manager",
			Level = 4,
			Permissions = {
				JOB_STORAGE = true,
				JOB_CRAFTING = true,
				JOB_HIRE = true,
			},
		},
		{
			Id = "owner",
			Name = "Owner",
			Level = 99,
			Permissions = {
				JOB_MANAGEMENT = true,
				BANK_ACCOUNT_MANAGE = true,
				BANK_ACCOUNT_WITHDRAW = true,
				BANK_ACCOUNT_DEPOSIT = true,
				BANK_ACCOUNT_TRANSACTIONS = true,
				BANK_ACCOUNT_BILL = true,
				BANK_ACCOUNT_BALANCE = true,
				JOB_MANAGE_EMPLOYEES = true,
				JOB_HIRE = true,
				JOB_FIRE = true,
				JOB_STORAGE = true,
				JOB_CRAFTING = true,
				TABLET_TWEET = true,
			},
		},
	},
})
