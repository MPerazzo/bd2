ALTER TABLE CONCILIATION
DROP CONSTRAINT "CONC_HOTEL_STATEMENT_FK";

ALTER TABLE CONCILIATION
DROP CONSTRAINT "CONC_PAYMENT_ORDER_FK";

ALTER TABLE HOTEL_STATEMENT
DROP CONSTRAINT "HOTEL_STATEMENT_SUPPLIER_FK";

ALTER TABLE PAYMENT_ORDER
DROP CONSTRAINT "PAYMENT_ORDER_SUPPLIER_FK";

DROP TABLE CONCILIATION;
DROP TABLE HOTEL_STATEMENT;
DROP TABLE PAYMENT_ORDER;
DROP TABLE SUPPLIER;

DROP SEQUENCE "HOTEL_STATEMENT_SEQ";
DROP SEQUENCE "PAYMENT_ORDER_SEQ";
DROP SEQUENCE "SUPPLIER_SEQ";

DROP PACKAGE "BDII_TEAM2"."CONCILIATE_PKG";