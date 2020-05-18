DROP TABLE HAEMO.xxha_inv_acc_receipt_tbl
/
CREATE TABLE HAEMO.XXHA_INV_ACC_RECEIPT_TBL
  (
    Reference_id            NUMBER,
    Item_no                 VARCHAR2(240),
    Inventory_item_id       NUMBER,
    Description             VARCHAR2(250),
    Organization_code       VARCHAR2(10),
    Organization_id         NUMBER,
    Revision                VARCHAR2(20),
    subinventory_code       VARCHAR2(25),
    Transaction_type        VARCHAR2(240),
    transaction_type_id     NUMBER,
    transaction_source_name VARCHAR2(240),
    transaction_source_id   NUMBER,
    transaction_date        DATE,
    Transaction_quantity    NUMBER,
    UOM                     VARCHAR2(25),
    Locator                 VARCHAR2(240),
    locator_id              NUMBER,
    Distribution_account_id NUMBER,
    from_serial_no          VARCHAR2(240),
    to_serial_no            VARCHAR2(240),
    Reference_Text          VARCHAR2(2000),
    Interface_Trans_id      NUMBER,
    trasaction_header_id    NUMBER,
    process_flag            VARCHAR2(240),
    Error_Msg               VARCHAR2(2400),
    CREATION_DATE           DATE,
    LAST_UPDATE_DATE        DATE,
    CREATED_BY              VARCHAR2(50 BYTE),
    LAST_UPDATED_BY         VARCHAR2(50 BYTE),
    LAST_UPDATE_LOGIN       NUMBER
  )
/
DROP SYNONYM xxha_inv_acc_receipt_tbl
/
CREATE SYNONYM xxha_inv_acc_receipt_tbl FOR haemo.xxha_inv_acc_receipt_tbl
/


