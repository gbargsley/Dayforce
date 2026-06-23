USE master;
GO
SELECT
   d.name AS DatabaseName,
   dek.encryptor_type AS EncryptorType,
   c.name AS CertificateName
FROM sys.dm_database_encryption_keys dek
LEFT JOIN sys.certificates c
   ON dek.encryptor_thumbprint = c.thumbprint
INNER JOIN sys.databases d
   ON dek.database_id = d.database_id;
GO