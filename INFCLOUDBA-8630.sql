--in upspayrollconfigcontrol
--{{dfid-client-secret-config}}
select ExternalSystemName, Password from ExternalSystem where ExternalSystemName = 'Payroll-DayforceIdentity-Config'
-- Payroll-DayforceIdentity-Config	843cb044-2f0d-4e19-8572-3548007a3fd3

--{{dfid-client-secret-config-monolith}}
select ExternalSystemName, Password from ExternalSystem where ExternalSystemName = 'DayforceIdentity-Config'
-- DayforceIdentity-Config	NULL




--upspayrolltestcontrol
--{{dfid-client-secret-test}}
select ExternalSystemName, Password from ExternalSystem where ExternalSystemName = 'Payroll-DayforceIdentity-Test'
--Payroll-DayforceIdentity-Test	843cb044-2f0d-4e19-8572-3548007a3fd3

--{{dfid-client-secret-test-monolith}}
select ExternalSystemName, Password from ExternalSystem where ExternalSystemName = 'DayforceIdentity-Test'
-- DayforceIdentity-Test	NULL




--in nademocontrol
--{{dfid-client-secret-predemo}}
select ExternalSystemName, Password from ExternalSystem where ExternalSystemName = 'Payroll-DayforceIdentity-PreProduction'
-- Payroll-DayforceIdentity-PreProduction	843cb044-2f0d-4e19-8572-3548007a3fd3


--{{dfid-client-secret-predemo-monolith}}
select ExternalSystemName, Password from ExternalSystem where ExternalSystemName in ('DayforceIdentity-PreProd', 'DayforceIdentity-PreProduction')
--DayforceIdentity-PreProd	c27830a0-b22c-4ebd-9212-d1926ef65293
--DayforceIdentity-PreProduction	NULL