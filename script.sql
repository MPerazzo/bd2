CREATE INDEX "BDII_TEAM2"."PAYMENT_ORDER_TR" ON "BDII_TEAM2"."PAYMENT_ORDER" ("SUPPLIER_ID", "RECORD_LOCATOR", "STATUS") 
  PCTFREE 10 INITRANS 2 MAXTRANS 255 COMPUTE STATISTICS 
  STORAGE(INITIAL 10240 NEXT 55296 MINEXTENTS 1 MAXEXTENTS 121
  PCTINCREASE 50 FREELISTS 1 FREELIST GROUPS 1 BUFFER_POOL DEFAULT FLASH_CACHE DEFAULT CELL_FLASH_CACHE DEFAULT)
  TABLESPACE "TEAM2_INDEXES";
  
CREATE INDEX "BDII_TEAM2"."HOTEL_STATEMENT_DB" ON "BDII_TEAM2"."HOTEL_STATEMENT" ("STATEMENT_LOCATOR", "STATUS") 
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

ALTER TABLE "BDII_TEAM2"."HOTEL_STATEMENT" PCTFREE 10 PCTUSED 40; 

ALTER TABLE "BDII_TEAM2"."HOTEL_STATEMENT" STORAGE (NEXT 10240 PCTINCREASE 50);

ALTER TABLE "BDII_TEAM2"."PAYMENT_ORDER" PCTFREE 10 PCTUSED 40; 

ALTER TABLE "BDII_TEAM2"."PAYMENT_ORDER" STORAGE (NEXT 10240 PCTINCREASE 50);

ALTER TABLE "BDII_TEAM2"."SUPPLIER" PCTFREE 10 PCTUSED 40; 

ALTER TABLE "BDII_TEAM2"."SUPPLIER" STORAGE(NEXT 10240 PCTINCREASE 50);

ALTER TABLE "BDII_TEAM2"."CONCILIATION" PCTFREE 10 PCTUSED 40; 

ALTER TABLE "BDII_TEAM2"."CONCILIATION" STORAGE(NEXT 10240 PCTINCREASE 50);

ALTER TABLE "BDII_TEAM2"."CONCILIATION" MODIFY(STATUS CHAR(20 BYTE));

ALTER SEQUENCE CONCILIATION_SEQ NOMAXVALUE;
