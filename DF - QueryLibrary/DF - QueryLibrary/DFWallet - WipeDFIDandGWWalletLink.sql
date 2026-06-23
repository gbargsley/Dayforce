/* *************************
   Users change of email in GW did not get pulled back up to DFID

   Remove DFID record
   Unlink DFID from Gateway WalletLink table
****************************** */
--Get associated SubjectId from DFID
db.resource.find({"_id":"<email address>"})

--Remove DFID record
db.resource.remove({"_id":"<email address>"})


--Unlink DFID from Gateway
select * from walletlink where subjectid = 'fd50efe5-dfbb-4b39-8708-7698732f6fc2'

begin tran
delete from walletlink where subjectid = 'fd50efe5-dfbb-4b39-8708-7698732f6fc2'

select * from walletlink where subjectid = 'fd50efe5-dfbb-4b39-8708-7698732f6fc2'

--Before will show records, after will not
--If all is well then COMMIT, if not then ROLLBACK
--COMMIT
--ROLLBACK
