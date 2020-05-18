CREATE OR REPLACE PACKAGE xxha_inv_acc_receipt_pkg
AS
  /* **********************************************************************************************************************
  * Object Name: APPS.xxha_inv_acc_receipt_pkg                                                                   *
  * Object Type: PACKAGE                                                                                                  *
  *                                                                                                                       *
  * Description: This PACKAGE used for increasing on hand quantity using account alias receipt Transaction type
  *
  *                                                                                                                       *
  *                                                                                                                       *
  * Change History                                                                                                        *
  *                                                                                                                       *
  * Ver        Date            Author               Description                                                           *
  * ------     -----------     -----------------    ---------------                                                       *
  * 1.0        05-may-2020     Venkat             Initial PACKAGE creation.                                             *
  *                                                                                                                       *
  ************************************************************************************************************************/
  PROCEDURE xxha_inv_acc_tab_insert_prc(
      p_item_no              VARCHAR2,
      p_organization_code    VARCHAR2,
      p_subinv               VARCHAR2,
      p_revision             VARCHAR2,
      p_transaction_quantity NUMBER,
      p_from_serial_no       VARCHAR2,
      p_reference            VARCHAR2 );
  PROCEDURE XXHA_INV_ACC_REC_IMPORT_PRC(
      errbuf OUT VARCHAR2 ,
      retcode OUT VARCHAR2,
      p_Transaction_type IN VARCHAR2,
      p_source           IN VARCHAR2,
      p_transaction_date VARCHAR2);
  PROCEDURE XXHA_INV_LOG_PRNT(
      P_DEBUG VARCHAR2,
      P_MSG   VARCHAR2);
  PROCEDURE XXHA_INV_OUT_PRNT;
END;