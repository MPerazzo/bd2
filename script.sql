CREATE INDEX "BDII_TEAM2"."PAYMENT_ORDER_OPT" ON "BDII_TEAM2"."PAYMENT_ORDER" ("SUPPLIER_ID", "RECORD_LOCATOR", "STATUS") 
  PCTFREE 10 INITRANS 2 MAXTRANS 255 COMPUTE STATISTICS 
  STORAGE(INITIAL 10240 NEXT 55296 MINEXTENTS 1 MAXEXTENTS 121
  PCTINCREASE 50 FREELISTS 1 FREELIST GROUPS 1 BUFFER_POOL DEFAULT FLASH_CACHE DEFAULT CELL_FLASH_CACHE DEFAULT)
  TABLESPACE "TEAM2_INDEXES";

DROP INDEX "CONCILIATION_PK";

DROP INDEX "CONC_DATES_IDX";

DROP INDEX "CONC_HOTEL_STATEMENT_IDX";

DROP INDEX "CONC_PAYMENT_ORDER_IDX";

DROP INDEX "CONC_STATEMENT_LOCATOR_IDX";

DROP INDEX "CONC_STATUS_IDX";

DROP INDEX "HOTEL_STATEMENT_PK";

DROP INDEX "PAYMENT_ORDER_PK";

DROP INDEX "SUPPLIER_PK";

DROP SEQUENCE "HOTEL_STATEMENT_SEQ";

DROP SEQUENCE "PAYMENT_ORDER_SEQ";

DROP SEQUENCE "SUPPLIER_SEQ";

ALTER TABLE "BDII_TEAM2"."HOTEL_STATEMENT" ADD CONSTRAINT "HOTEL_STATEMENT_PK" PRIMARY KEY ("ID") using index TABLESPACE "TEAM2_INDEXES";

ALTER TABLE "BDII_TEAM2"."SUPPLIER" ADD CONSTRAINT "SUPPLIER_PK" PRIMARY KEY ("ID") using index TABLESPACE "TEAM2_INDEXES";

ALTER TABLE "BDII_TEAM2"."PAYMENT_ORDER" ADD CONSTRAINT "PAYMENT_ORDER_PK" PRIMARY KEY ("ID") using index TABLESPACE "TEAM2_INDEXES";

ALTER TABLE "BDII_TEAM2"."HOTEL_STATEMENT" STORAGE (NEXT 32768);

ALTER TABLE "BDII_TEAM2"."PAYMENT_ORDER" STORAGE (NEXT 32768);

ALTER TABLE "BDII_TEAM2"."SUPPLIER" STORAGE(NEXT 32768);

ALTER TABLE "BDII_TEAM2"."CONCILIATION" PCTFREE 10 PCTUSED 40; 

ALTER TABLE "BDII_TEAM2"."CONCILIATION" STORAGE(NEXT 32768 PCTINCREASE 50);

ALTER TABLE "BDII_TEAM2"."CONCILIATION" MODIFY(STATUS CHAR(20 BYTE));

ALTER SEQUENCE CONCILIATION_SEQ NOMAXVALUE;

/* Procedure Optimized */

create or replace PACKAGE BODY  "CONCILIATE_PKG" AS

  -- Conciliacion de una reserva
  PROCEDURE conciliate_booking ( pStatementLocator VARCHAR, pHsId NUMBER, pSupplier NUMBER, pRecordLocator VARCHAR, 
  								 pAmount NUMBER, pCurrency VARCHAR, vTolPercentage NUMBER, vTolMax NUMBER ) AS
    vPoId NUMBER(10);
    vAmount NUMBER(10,2);
    vCurrency CHAR(3);
    vStatus CHAR(20);
    vCheckinDate DATE;
    vCheckoutDate DATE;
  BEGIN

      -- Buscar la PO asociada
      select /*+PAYMENT_ORDER_TR*/ po.ID, po.TOTAL_COST, po.TOTAL_COST_CURRENCY, po.STATUS, po.CHECKIN, po.CHECKOUT
      into vPoId, vAmount, vCurrency, vStatus, vCheckinDate, vCheckoutDate
      from PAYMENT_ORDER po
      where po.supplier_id = pSupplier
      and lower(po.record_locator) = lower(pRecordLocator)
      and rtrim(ltrim(po.status)) = 'PENDING';

      -- Si no paso la fecha de checkout no se puede pagar aun
      IF vCheckOutDate>SYSDATE THEN
          -- Registrar que la reserva aun no puede conciliarse por estar pendiente su fecha de checkout
          dbms_output.put_line('    Checkout Pending');
          INSERT INTO CONCILIATION (
              ID, HOTEL_STATEMENT_ID, STATEMENT_LOCATOR, PAYMENT_ORDER_ID, 
              CONCILIATED_AMOUNT, CONCILIATED_AMOUNT_CURRENCY, 
              ADJUSTMENT_AMOUNT, ADJUSTMENT_AMOUNT_CURRENCY,
              STATUS, CREATED, MODIFIED)
          VALUES (CONCILIATION_SEQ.nextval, pHsId, pStatementLocator, null,
              null, null, null, null,
              'CHECKOUT_PENDING',sysdate,sysdate);
          UPDATE HOTEL_STATEMENT SET STATUS = 'CHECKOUT_PENDING', MODIFIED = SYSDATE
          WHERE ID = pHsId;
      -- Si la moneda de conciliacion y la del hotelero no coinciden
      ELSIF vCurrency NOT LIKE pCurrency THEN
          -- Registrar que la moneda indicada en el extracto no es la correcta
          dbms_output.put_line('    Wrong Currency');
          INSERT INTO CONCILIATION (
              ID, HOTEL_STATEMENT_ID, STATEMENT_LOCATOR, PAYMENT_ORDER_ID, 
              CONCILIATED_AMOUNT, CONCILIATED_AMOUNT_CURRENCY, 
              ADJUSTMENT_AMOUNT, ADJUSTMENT_AMOUNT_CURRENCY,
              STATUS, CREATED, MODIFIED)
          VALUES (CONCILIATION_SEQ.nextval, pHsId, pStatementLocator, null,
              null, null, null, null,
              'WRONG_CURRENCY',sysdate,sysdate);
          UPDATE HOTEL_STATEMENT SET STATUS = 'WRONG_CURRENCY', MODIFIED = SYSDATE
          WHERE ID = pHsId;
      -- Si el monto solicitado por el hotelero esta dentro de los limites de tolerancia
      ELSIF ( ((vAmount-pAmount)<((vTolPercentage/100)*pAmount)) AND ((vAmount-pAmount)<vTolMax) ) THEN
          -- Registrar que se aprueba la conciliacion de la reserva
          dbms_output.put_line('    Conciliated');
          INSERT INTO CONCILIATION (
              ID, HOTEL_STATEMENT_ID, STATEMENT_LOCATOR, PAYMENT_ORDER_ID, 
              CONCILIATED_AMOUNT, CONCILIATED_AMOUNT_CURRENCY, 
              ADJUSTMENT_AMOUNT, ADJUSTMENT_AMOUNT_CURRENCY,
              STATUS, CREATED, MODIFIED)
          VALUES (CONCILIATION_SEQ.nextval, pHsId, pStatementLocator, vPoId,
              pAmount, pCurrency, round(vAmount-pAmount,2), pCurrency,
              'CONCILIATED',sysdate,sysdate);
          UPDATE HOTEL_STATEMENT SET STATUS = 'CONCILIATED', MODIFIED = SYSDATE
          WHERE ID = pHsId;
          UPDATE PAYMENT_ORDER SET STATUS = 'CONCILIATED', MODIFIED = SYSDATE
          WHERE ID = vPoId;
      -- Si el monto solicitado por el hotelero no esta dentro de los limites de tolerancia
      ELSE
          -- Registrar que la reserva no puede conciliarse por diferencia de monto
          dbms_output.put_line('    Error Tolerance');
          INSERT INTO CONCILIATION (
              ID, HOTEL_STATEMENT_ID, STATEMENT_LOCATOR, PAYMENT_ORDER_ID, 
              CONCILIATED_AMOUNT, CONCILIATED_AMOUNT_CURRENCY, 
              ADJUSTMENT_AMOUNT, ADJUSTMENT_AMOUNT_CURRENCY,
              STATUS, CREATED, MODIFIED)
          VALUES (CONCILIATION_SEQ.nextval, pHsId, pStatementLocator, vPoId,
              pAmount, pCurrency, null, null,
              'ERROR_TOLERANCE',sysdate,sysdate);
          UPDATE HOTEL_STATEMENT SET STATUS = 'ERROR_TOLERANCE', MODIFIED = SYSDATE
          WHERE ID = pHsId;
      END IF;

  EXCEPTION
      WHEN NO_DATA_FOUND THEN
          -- Registrar que no se encontro una reserva de las caracteriticas que el hotelero indico
          dbms_output.put_line('    Not Found');
          INSERT INTO CONCILIATION (
              ID, HOTEL_STATEMENT_ID, STATEMENT_LOCATOR, PAYMENT_ORDER_ID, 
              CONCILIATED_AMOUNT, CONCILIATED_AMOUNT_CURRENCY, 
              ADJUSTMENT_AMOUNT, ADJUSTMENT_AMOUNT_CURRENCY,
              STATUS, CREATED, MODIFIED)
          VALUES (CONCILIATION_SEQ.nextval, pHsId, pStatementLocator, null,
              null, null, null, null,
              'NOT_FOUND',sysdate,sysdate);
          UPDATE HOTEL_STATEMENT SET STATUS = 'NOT_FOUND'
          WHERE ID = pHsId;
  END conciliate_booking;

  -- Conciliacion de todos los extractos pendientes
  PROCEDURE conciliate_all_statements AS
  BEGIN        

    -- Recorro los extractos pendientes
    FOR R IN ( 
        SELECT hs.STATEMENT_LOCATOR, hs.ID, hs.SUPPLIER_ID, hs.RECORD_LOCATOR, hs.AMOUNT, hs.CURRENCY, 
        s.CONCILIATION_TOLERANCE_PERC, s.CONCILIATION_TOLERANCE_MAX
        FROM supplier s join hotel_statement hs on s.ID = hs.SUPPLIER_ID
        WHERE LTRIM(RTRIM(hs.STATUS)) = 'PENDING'
   ) LOOP
   
    	-- Concilio el extracto actual
    	conciliate_booking(R.STATEMENT_LOCATOR, R.ID, R.SUPPLIER_ID, R.RECORD_LOCATOR, R.AMOUNT, R.CURRENCY,
        R.CONCILIATION_TOLERANCE_PERC, R.CONCILIATION_TOLERANCE_MAX);
        
    END LOOP;
    
    COMMIT;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            dbms_output.put_line('Not Found');

  END conciliate_all_statements;

  PROCEDURE profiler AS
    timestart NUMBER;
    BEGIN        

    dbms_output.disable();
    
    timestart := dbms_utility.get_time();
  
    conciliate_all_statements();
    
    dbms_output.enable();
  
    dbms_output.put_line('profile: ' || to_char((dbms_utility.get_time() - timestart)*10) || 'ms');
    
  END profiler;

END CONCILIATE_PKG;



