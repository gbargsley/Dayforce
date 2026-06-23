SELECT  distinct
    fk.name AS FK_name,
    tp.name AS ReferencingTable,
    cp.name AS ReferencingColumn
FROM sys.foreign_keys AS fk
INNER JOIN sys.foreign_key_columns AS fkc 
    ON fk.object_id = fkc.constraint_object_id
INNER JOIN sys.tables AS tp 
    ON fkc.parent_object_id = tp.object_id
INNER JOIN sys.columns AS cp 
    ON fkc.parent_object_id = cp.object_id AND fkc.parent_column_id = cp.column_id
INNER JOIN sys.tables AS tr 
    ON fkc.referenced_object_id = tr.object_id
WHERE tr.name = 'Employee';