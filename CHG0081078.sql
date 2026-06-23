Select top 100 * from Govtransaction With (NOLOCK)   order by GovTransactionId desc


Select Status,EbmsMessageId,EbmsRefToMessageId,InsertionTime from OutMessages Where ConversationId = 64690

Select Status,EbmsMessageId,EbmsRefToMessageId,InsertionTime,[ModificationTime],[Operation] ,
[PMode] from InMessages Where  EbmsRefToMessageId = 'db04df92-326f-415a-9f0e-eb5679d6d133@10.138.51.133'