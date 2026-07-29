table.insert(_defaultJobData, {
	Type = "Company",
	LastUpdated = 1784524361,
	Id = "digitalden",
	Name = "Digital Den",
	Salary = 600,
	SalaryTier = 1,
	Grades = {
		{
			Id = "bbemployee",
			Name = "Basic Bitch Employee",
			Level = 1,
			Permissions = {
				JOB_STORAGE = true,
				JOB_CRAFTING = true,
			},
		},
		{
			Id = "employee",
			Name = "Employee",
			Level = 2,
			Permissions = {
				JOB_STORAGE = true,
				JOB_CRAFTING = true,
			},
		},
		{
			Id = "manager",
			Name = "Manager",
			Level = 5,
			Permissions = {
				JOB_STORAGE = true,
				JOB_CRAFTING = true,
				JOB_HIRE = true,
				JOB_FIRE = true,
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
			},
		},
	},
})
