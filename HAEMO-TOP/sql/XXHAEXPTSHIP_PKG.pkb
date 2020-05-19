create or replace PACKAGE BODY      XXHAEXPTSHIP_PKG as

/*===========================================================================
  PACKAGE NAME:       XXHAEXPTSHIP_PKG

  DESCRIPTION:        Package to Generate Invoice number of the Sales Order

  OWNER:              Sriram Ganesan

  HISTORY:            05-May-2020      Initial Creation


  ===========================================================================*/
  

FUNCTION get_inv_num (
                 p_line_id    IN     NUMBER
                ,p_order_num  IN     VARCHAR2
                ,p_org_id     IN     NUMBER)
                RETURN VARCHAR2
IS

  v_inv_num  VARCHAR2(100);

BEGIN

      SELECT rcta.trx_number
      INTO v_inv_num
      FROM ra_customer_trx_all rcta,
        ra_customer_Trx_lines_all rctla
      WHERE rctla.interface_line_attribute6 = TO_CHAR (p_line_id)
      AND rcta.customer_trx_id              = rctla.customer_trx_id
      AND rcta.interface_header_attribute1  = TO_CHAR (p_order_num)
      AND rcta.ct_reference                 = TO_CHAR (p_order_num)
      AND rcta.org_id                       = p_org_id; 

RETURN v_inv_num;

EXCEPTION
    WHEN others THEN
RETURN NULL;

END get_inv_num;

END XXHAEXPTSHIP_PKG;