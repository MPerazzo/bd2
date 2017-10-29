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

  -- Conciliacion de un extracto
  PROCEDURE conciliate_statement ( pStatementLocator VARCHAR, pId NUMBER, pSupplierId NUMBER, pRecordLocator VARCHAR, 
                                            pAmount NUMBER, pCurrency VARCHAR ) AS
  		vTolPercentage NUMBER(10,2);
  		vTolMax NUMBER(10,2);
  BEGIN

    dbms_output.put_line('Conciliating statement '||pStatementLocator);

    	-- Recupero los parametros de tolerancia del proveedor
    	dbms_output.put_line('  Retrieving supplier '||pRecordLocator);
    	SELECT /*+SUPPLIER_PK*/ s.CONCILIATION_TOLERANCE_PERC, s.CONCILIATION_TOLERANCE_MAX
    	INTO vTolPercentage, vTolMax
    	FROM supplier s
    	WHERE s.ID = pSupplierId;

        -- Concilio una reserva
        dbms_output.put_line('  Conciliating booking '||pRecordLocator);
        conciliate_booking(pStatementLocator,pId,pSupplierId,pRecordLocator,pAmount,pCurrency,vTolPercentage,vTolMax);

    -- El extracto debe procesarse completo
    COMMIT;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            dbms_output.put_line('Not Found');

  END conciliate_statement;

  -- Conciliacion de todos los extractos pendientes
  PROCEDURE conciliate_all_statements AS
  BEGIN        

    -- Recorro los extractos pendientes
    FOR R IN ( 
        SELECT hs.STATEMENT_LOCATOR, hs.ID, hs.SUPPLIER_ID, hs.RECORD_LOCATOR, hs.AMOUNT, hs.CURRENCY
        FROM hotel_statement hs
        WHERE LTRIM(RTRIM(hs.STATUS)) = 'PENDING'
   ) LOOP
   
    	-- Concilio el extracto actual
    	conciliate_statement(R.STATEMENT_LOCATOR, R.ID, R.SUPPLIER_ID, R.RECORD_LOCATOR, R.AMOUNT, R.CURRENCY);
    END LOOP;

  END conciliate_all_statements;

  PROCEDURE profiler AS
    timestart NUMBER;
    BEGIN        

    dbms_output.disable();
    
    timestart := dbms_utility.get_time();
  
    conciliate_all_statements();
    
    dbms_output.enable();
  
    dbms_output.put_line('profile: ' || to_char(dbms_utility.get_time() - timestart) || 'cs');
    
  END profiler;

END CONCILIATE_PKG;
