# Import dbatools module
Import-Module "F:\Temp\GB\dbatools-2.7.23\dbatools-2.7.23\dbatools.psm1"

# Compare schema between two databases
Compare-DbaDbSchema `
    -Source "AZG2SIXSQL002" -SourceDatabase "sfparksconfig2" `
    -Destination "azg1sixsql01dnn.custadds.com" -DestinationDatabase "sfparks" `
    -IncludeIdentical:$false `
    -OutputType "Difference"
