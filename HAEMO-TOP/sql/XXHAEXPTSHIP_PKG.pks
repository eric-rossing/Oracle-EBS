create or replace PACKAGE XXHAEXPTSHIP_PKG as
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
                RETURN VARCHAR2;


END XXHAEXPTSHIP_PKG;