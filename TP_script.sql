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



-------------------------  OPTIMIZACIÓN --------------------

/* La optimización se realiza a partir de la creación de índices o eliminando aquellos que no sean utilizados.
   Para eso se analizan las queries con statements delete, update o select. */

/* Considerar que índices existentes se van a modificar indicando UNIQUE para la precisión en la predicción
del plan a utilizar */

## CREACIÓN DE ÍNDICES A PARTIR DEL ANÁLISIS DE STATEMENTS

## Select Statements

## 1)

	SELECT distinct hs.statement_locator
	FROM hotel_statement hs
	WHERE LTRIM(RTRIM(hs.STATUS)) = 'PENDING'

/* La query no va a poder ser optimizada dando que gran parte de las hotel_statement se van a encontrar en 'PENDING' e indexar
por este campo generaría un TABLE_ACCESS_FULL de todas formas */

## 2)

	SELECT /*+SUPPLIER_PK*/ s.CONCILIATION_TOLERANCE_PERC, s.CONCILIATION_TOLERANCE_MAX
	FROM supplier s
	WHERE s.ID = R.SUPPLIER_ID;

/* La query no puede ser optimizada ya que ya hay un índice existente sobre ID de supplier. El índice
se debe modificar para que sea UNIQUE como corresponde. */

## 3)

	SELECT /*+HOTEL_STATEMENT_PK*/ hs.ID, hs.SUPPLIER_ID, hs.RECORD_LOCATOR, hs.AMOUNT, hs.CURRENCY
	FROM hotel_statement hs
	WHERE hs.statement_locator = pStatementLocator
	AND LTRIM(RTRIM(hs.STATUS)) = 'PENDING';

/* Primero el uso de HOTEL_STATEMENT_PK no va a impactar en la performance de la query dado que la misma es sobre
el id de la tabla y no se filtra por el mismo en la consulta por lo que el plan va a ser TABLE_ACCESS_FULL. Para
evitar un acceso completo se creó un índice sobre (STATEMENT_LOCATOR, STATUS) el cuál no es UNIQUE debido a la lógica
de negocio del problema. Como no es UNIQUE se obtiene un INDEX_RANGE_SCAN como parte del plan. */

## 4)

      select /*+HASH*/ po.ID, po.TOTAL_COST, po.TOTAL_COST_CURRENCY, po.STATUS, po.CHECKIN, po.CHECKOUT
      into vPoId, vAmount, vCurrency, vStatus, vCheckinDate, vCheckoutDate
      from PAYMENT_ORDER po, SUPPLIER s
      where po.supplier_id = pSupplier
      and po.supplier_id = s.id
      and lower(po.record_locator) = lower(pRecordLocator)
      and rtrim(ltrim(po.status)) = 'PENDING';

/* Se propone el uso de un HASH cuando en realidad se pueden usar índices para reducir el costo de la operación.
Primero se cuenta con el índice ya creado SUPPLIER_PK y además se va a crear un nuevo índice sobre (SUPPLIER_ID, RECORD_LOCATOR, STATUS)
el cuál no va a ser UNIQUE por la lógica del negocio. Como resultado el plan va a contar con NESTED_LOOPS
 + INDEX UNIQUE SCAN (SUPPLIER_PK) + INDEX RANGE SCAN (nuevo índice). */

## Nuevos índices para planes de menor costo

CREATE INDEX "BDII_TEAM2"."PAYMENT_ORDER_TR" ON "BDII_TEAM2"."PAYMENT_ORDER" ("SUPPLIER_ID", "RECORD_LOCATOR", "STATUS") 
  PCTFREE 10 INITRANS 2 MAXTRANS 255 COMPUTE STATISTICS 
  STORAGE(INITIAL 10240 NEXT 55296 MINEXTENTS 1 MAXEXTENTS 121
  PCTINCREASE 50 FREELISTS 1 FREELIST GROUPS 1 BUFFER_POOL DEFAULT FLASH_CACHE DEFAULT CELL_FLASH_CACHE DEFAULT)
  TABLESPACE "TEAM2_INDEXES" ;
  
CREATE INDEX "BDII_TEAM2"."HOTEL_STATEMENT_DB" ON "BDII_TEAM2"."HOTEL_STATEMENT" ("STATEMENT_LOCATOR", "STATUS") 
  PCTFREE 10 INITRANS 2 MAXTRANS 255 COMPUTE STATISTICS 
  STORAGE(INITIAL 10240 NEXT 55296 MINEXTENTS 1 MAXEXTENTS 121
  PCTINCREASE 50 FREELISTS 1 FREELIST GROUPS 1 BUFFER_POOL DEFAULT FLASH_CACHE DEFAULT CELL_FLASH_CACHE DEFAULT)
  TABLESPACE "TEAM2_INDEXES" ;

## Update Statements

/* Por suerte, todos los UPDATES se realizan sobre la condición de algun ID de alguna tabla y ya contamos con
índices sobre cada ID de cada tabla existente. Lo único que habría que modificar es que los índices sean UNIQUE
por la lógica de negocio y para que indique como plan un INDEX_UNIQUE_SCAN en vez de INDEX_RANGE_SCAN.

## Delete Statements

/* No se cuenta con ninguna sentencia de este tipo */


## ELIMINACIÓN DE ÍNDICES A PARTIR DEL ANÁLISIS DE STATEMENTS

/* Todos los índices "PK" (sobre ID) de las tablas HOTEL_STATEMENT, PAYMENT_ORDER y SUPPLIER son necesarios
dado que se usan en todos los UPDATE y en algunos SELECT dependiendo del caso, por lo tanto no se eliminará
ninguna de estas. */

/* La tabla CONCILIATION cuenta con una gran cantidad de índices cuando en la misma no se va a realizar ningún
UPDATE, ni DELETE ni SELECT. Esto genera mucho overhead en la operación de INSERT sobre la tabla la cuál es fundamental
dado las características del negocio. POr este motivo se procede a eliminar los índices de la tabla */

DROP INDEX "CONCILIATION_PK";

DROP INDEX "CONC_DATES_IDX";

DROP INDEX "CONC_HOTEL_STATEMENT_IDX";

DROP INDEX "CONC_PAYMENT_ORDER_IDX";

DROP INDEX "CONC_STATEMENT_LOCATOR_IDX";

DROP INDEX "CONC_STATUS_IDX";

DUDA : Optimizaciones vs Representacion de la relación en el lenguaje de negocio ?
(Por ejemplo Unique, Foreign Keys)


##CÁLCULO DE TIEMPO DE EJECUCIÓN

PROCEDURE conciliate_all_statements AS
  timestart NUMBER;
  BEGIN

  timestart := dbms_utility.get_time();

  /*  ... LÓGICA ... */

  dbms_output.put_line('TIEMPO FINAL: ' || to_char(dbms_utility.get_time()-timestart));

  END

/* dbms_utility.get_time() computa centésimas de segundo */

