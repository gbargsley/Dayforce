# Example: integrated auth, don't auto-install dbatools
.\Compare-DbSchemaAndIndexes.ps1 `
  -SourceInstance 'AZG2SIXSQL002' -SourceDatabase 'sfparksconfig2' `
  -DestInstance   'azg1sixsql01dnn' -DestDatabase   'sfparks' `
  -OutputFolder 'F:\Temp\GB\Compare\sfparksconfig2_vs_sfparks'

