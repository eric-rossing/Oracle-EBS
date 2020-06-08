CREATE OR REPLACE PACKAGE xxha_inv_move_order_txfr_pkg
AS

/*******************************************************************************************************************
  * Object Name: APPS.xxha_inv_move_order_txfr_pkg                                                                   *
  * Object Type: PACKAGE                                                                                                  *
  *                                                                                                                       *
  * Description: This PACKAGE used for creating Move Order using webadi
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
  
  PROCEDURE xxha_inv_move_order_insert_prc
  (
  p_itemno     VARCHAR2,
  p_revision   VARCHAR2,
  p_desc       VARCHAR2,
  p_source_inv VARCHAR2,
  P_dest_inv   VARCHAR2,
  p_organ      VARCHAR2,
  p_qty        NUMBER,
  p_from_serial_no  VARCHAR2
  );
  
  
  PROCEDURE xxha_inv_move_order_import_prc
  (
   x_errbuf OUT VARCHAR2 ,
   x_retcode OUT VARCHAR2,
   p_transaction_type VARCHAR2
   );
   
   PROCEDURE xxha_inv_move_prt_prc
   (
   p_debug VARCHAR2,
   p_msg   VARCHAR2);
   
   PROCEDURE xxha_inv_move_out_prnt;
   
   
   
  
  
  END xxha_inv_move_order_txfr_pkg;
  
  
  
  
  