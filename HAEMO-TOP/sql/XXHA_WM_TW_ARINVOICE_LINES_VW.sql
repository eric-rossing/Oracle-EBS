
  CREATE OR REPLACE FORCE VIEW "APPS"."XXHA_WM_TW_ARINVOICE_LINES_VW" ("CUSTOMER_TRX_LINE_ID", "CUSTOMER_TRX_ID", "LINE_NUMBER", "DELIVERY_NAME", "BILLED_FROM_DATE", "BILLED_TO_DATE", "INVENTORY_ITEM", "ITEM_DESCRIPTION", "GTIN", "UNIT_SELLING_PRICE", "UNIT_STANDARD_PRICE", "QUANTITY", "UOM_CODE", "QUANTITY_DELIVERED", "QUANTITY_DELIVERED_UOM", "UNIT_QUANTITY", "UNIT_QUANTITY_UOM", "EXTENDED_AMOUNT", "ORIG_SYS_LINE_REF") AS 
  SELECT 
  ctl.customer_trx_line_id,
  ctl.customer_trx_id,
  ctl.line_number,
  case when ctl.interface_line_context = 'ORDER ENTRY' then ctl.interface_line_attribute3 else null end delivery_name,
  case when ctl.interface_line_context = 'OKS CONTRACTS' then TO_DATE(ctl.interface_line_attribute4,'YYYY/MM/DD') else null end billed_from_date,
  case when ctl.interface_line_context = 'OKS CONTRACTS' then TO_DATE(ctl.interface_line_attribute5,'YYYY/MM/DD') else null end billed_to_date,
  msib.segment1 AS inventory_item,
  msib.description AS ITEM_DESCRIPTION, -- Eric Rossing - 7/2/2015 - add Item Description to query
  decode (ctl.uom_code, 'Ca', xxha_robar_pkg.gtin_number(ctl.inventory_item_id, 3), 'Ea', xxha_robar_pkg.gtin_number(ctl.inventory_item_id, 1)) gtin,
  ctl.unit_selling_price,
  ctl.unit_standard_price,
--  ctl.sales_order_line,
  ABS(nvl(ctl.quantity_invoiced,0)+nvl(ctl.quantity_credited,0)) AS quantity,
  ctl.uom_code,
  ctl.quantity_invoiced AS quantity_delivered,
  ctl.uom_code AS quantity_delivered_uom,
  case when ctl.uom_code='Ca' then muc.conversion_rate else 1 end unit_quantity,
  case when ctl.uom_code='Ca' then 'Ea' else ctl.uom_code end unit_quantity_uom,
  ABS(ctl.EXTENDED_AMOUNT),
  ol.orig_sys_line_ref
--  ol.line_number AS order_line_number,
--  oh.order_number,
--  oh.org_id as order_org_id
FROM ra_customer_trx_lines_all ctl,
  ra_customer_trx_all ct,
  ra_cust_trx_types_all ctt,
  oe_order_lines_all ol,
--  oe_order_headers_all oh,
  mtl_system_items_b msib, -- Eric Rossing - 7/2/2015 - add Item Description to query
  mtl_uom_conversions muc
WHERE ctl.customer_trx_id = ct.customer_trx_id
 AND ct.cust_trx_type_id = ctt.cust_trx_type_id
 AND ct.org_id = ctl.org_id
 AND ct.org_id = ctt.org_id
 AND ctt.type NOT IN('DEP',   'GUAR',   'BR')
 AND ctl.interface_line_attribute6 = to_char(ol.line_id(+))
-- AND ol.header_id=oh.header_id (+)
 AND ctl.line_type = 'LINE'
 AND ctl.inventory_item_id = msib.inventory_item_id(+) -- Eric Rossing - 7/2/2015 - add Item Description to query -- 2/26/2016 - link to Trx Line, not Order Line
 AND msib.organization_id(+)=103                      -- Eric Rossing - 7/2/2015 - add Item Description to query -- 2/26/2016 - link to Trx Line, not Order Line
 AND ctl.inventory_item_id = muc.inventory_item_id(+)
 and ctl.uom_code = muc.uom_code(+)
ORDER BY ctl.line_number;
