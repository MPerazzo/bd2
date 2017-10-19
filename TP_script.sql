/*
1. Se descubrio que el procedure no podia correr debido a diversos problemas los cuales se corrigen a continuacion: 

SQL utilizado para averiguar el nombre de los archivos que se debian modificar:

select file_name,tablespace_name,bytes/1024,AUTOEXTENSIBLE,status from dba_data_files where TABLESPACE_NAME = 'SPACE' order by tablespace_name;

Table spaces modificados:

TEAM2_DATA
TEAM2_INDEXES */

alter database datafile '/dbases/oracle11g/u01/app/oracle/product/11.2.0/db_1/dbs/team2_data.ora' AUTOEXTEND ON;
alter database datafile '/dbases/oracle11g/u01/app/oracle/product/11.2.0/db_1/dbs/team2_indexes.ora' AUTOEXTEND ON;

/*
	Existe la posibilidad de que se generen excepciones, por lo que se agregaron try catch para atrapar las mismas.
*/

  EXCEPTION
    WHEN NO_DATA_FOUND THEN
        dbms_output.put_line('No data was found.');

/* Como nos tiraba error de overflow desactivamos lo siguiente */
dbms_output.disable();

--This enables the output printing and we need a huge buffer size for it to work
dbms_output.enable(buffer_size);

## ÍNDICES

## Eliminando índices de CONCILIATION dado que en esta tabla no se van a realizar selects, ni updates ni deletes.

DROP INDEX "CONC_DATES_IDX";

DROP INDEX "CONC_HOTEL_STATEMENT_IDX";

DROP INDEX "CONC_PAYMENT_ORDER_IDX";

DROP INDEX "CONC_STATEMENT_LOCATOR_IDX";

DROP INDEX "CONC_STATUS_IDX";


CREATE INDEX "BDII_TEAM2"."HOTEL_STATEMENT_TR" ON "BDII_TEAM2"."PAYMENT_ORDER" ("SUPPLIER_ID", "RECORD_LOCATOR", "STATUS") 
  PCTFREE 10 INITRANS 2 MAXTRANS 255 COMPUTE STATISTICS 
  STORAGE(INITIAL 10240 NEXT 55296 MINEXTENTS 1 MAXEXTENTS 121
  PCTINCREASE 50 FREELISTS 1 FREELIST GROUPS 1 BUFFER_POOL DEFAULT FLASH_CACHE DEFAULT CELL_FLASH_CACHE DEFAULT)
  TABLESPACE "TEAM2_INDEXES" ;
  
CREATE INDEX "BDII_TEAM2"."HOTEL_STATEMENT_DB" ON "BDII_TEAM2"."HOTEL_STATEMENT" ("STATEMENT_LOCATOR", "STATUS") 
  PCTFREE 10 INITRANS 2 MAXTRANS 255 COMPUTE STATISTICS 
  STORAGE(INITIAL 10240 NEXT 55296 MINEXTENTS 1 MAXEXTENTS 121
  PCTINCREASE 50 FREELISTS 1 FREELIST GROUPS 1 BUFFER_POOL DEFAULT FLASH_CACHE DEFAULT CELL_FLASH_CACHE DEFAULT)
  TABLESPACE "TEAM2_INDEXES" ;