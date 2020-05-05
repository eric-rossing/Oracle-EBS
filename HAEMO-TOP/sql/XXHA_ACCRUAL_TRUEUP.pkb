CREATE OR REPLACE PACKAGE BODY XXHA_ACCRUAL_TRUEUP
IS
 /*
 * Package to store and maintain Galaxy Trueup Report Data
 * (this package only populates tables that contain the
 * Trueup data. The trueup report itself will be generated
 * by a separate Oracle Report)
 *
 * Revision History
 * =========
 * When Rev Who What
 * ------------------------------
 * 08/01/2018 1.0 imenzies CR# ESC116166 Initial Version of Trueup Report
 * 03/04/2019 1.1 imenzies CR# New Site Exclusion and ADJ-0625B-00
 */
 --Procedure to submit request to generate report
 PROCEDURE RUN_REPORT (p_query_id IN VARCHAR2)
 IS
 l_excel_layout BOOLEAN;
 l_notification BOOLEAN;
 l_username VARCHAR2 (40) := fnd_global.user_name;
 l_req_id NUMBER;
 BEGIN
 l_excel_layout :=
 FND_REQUEST.ADD_LAYOUT ('HAEMO',
 'XXHATRUEUPREP',
 'en',
 'US',
 'EXCEL');


 l_notification := FND_REQUEST.ADD_NOTIFICATION (l_username);

 l_req_id :=
 FND_REQUEST.SUBMIT_REQUEST (application => 'HAEMO',
 program => 'XXHATRUEUPREP_CP',
 argument1 => p_query_id);
 COMMIT;

 FND_FILE.PUT_LINE (
 FND_FILE.LOG,
 'Submitting XXHA TRUEUP Report program request id ' || l_req_id);
 END RUN_REPORT;

 --Function to detect if data has already been generated for query_id
 FUNCTION GET_REQ (p_query_id IN VARCHAR2)
 RETURN NUMBER
 IS
 l_req_id NUMBER;
 BEGIN
 SELECT NVL (MAX (request_id), 0) req_id
 INTO l_req_id
 FROM fnd_concurrent_requests fcr
 WHERE concurrent_program_id = fnd_global.conc_program_id
 AND request_id <> fnd_global.conc_request_id
 AND argument1 = p_query_id
 AND phase_code = 'R';

 RETURN l_req_id;
 END GET_REQ;

 --Procedure to populate trueup data for a given query_id
 PROCEDURE GET_DATA (errbuf OUT VARCHAR2,
 retcode OUT NUMBER,
 p_query_id IN NUMBER)
 IS
 l_query_id_c VARCHAR2 (20) := '' || p_query_id;
 l_has_data VARCHAR2 (1) := HAS_DATA (p_query_id);
 l_query_name VARCHAR2 (240);
 l_bad_dates NUMBER (1);
 l_future_date NUMBER (1);
 l_cust_count NUMBER;
 l_site_count NUMBER;
 l_bsa_count NUMBER;
 l_max_device_excl NUMBER;
 l_bad_params BOOLEAN := FALSE;
 l_bad_price NUMBER (1);
 l_bad_price_col VARCHAR2(240);
 l_req_id NUMBER;
 BEGIN
 retcode := 0;

 SELECT query_name,
 CASE WHEN qh.end_date < qh.start_date THEN 1 ELSE 0 END bad_date,
 CASE WHEN qh.start_date > SYSDATE THEN 1 ELSE 0 END future_date,
 NVL (
 (SELECT COUNT (*) cust_ct
 FROM xxha_accr_trueup_query_cust qc
 WHERE qc.query_id = qh.query_id AND qc.active_flag = 'Y'),
 0)
 cust_ct,
 NVL (
 (SELECT COUNT (*) site_ct
 FROM xxha_accr_trueup_query_site qs
 WHERE qs.query_id = qh.query_id AND qs.active_flag = 'Y'),
 0)
 site_ct,
 NVL (
 (SELECT COUNT (*) bsa_ct
 FROM xxha_accr_trueup_bsa qb
 WHERE qb.query_id = qh.query_id AND qb.active_flag = 'Y'),
 0)
 bsa_ct,
 nvl(no_of_devices,1000000) no_devices 
 INTO l_query_name,
 l_bad_dates,
 l_future_date,
 l_cust_count,
 l_site_count,
 l_bsa_count,
 l_max_device_excl
 FROM xxha_accr_trueup_query_hdr qh
 WHERE qh.query_id = p_query_id;

 IF (l_bad_dates = 1)
 THEN
 l_bad_params := TRUE;
 FND_FILE.PUT_LINE (FND_FILE.LOG, 'Start Date after End Date');
 END IF;

 IF (l_future_date = 1)
 THEN
 l_bad_params := TRUE;
 FND_FILE.PUT_LINE (FND_FILE.LOG, 'Start Date in future');
 END IF;

 IF (l_cust_count = 0)
 THEN
 l_bad_params := TRUE;
 FND_FILE.PUT_LINE (FND_FILE.LOG, 'No Bill-to Customers selected');
 END IF;

 IF (l_site_count = 0)
 THEN
 l_bad_params := TRUE;
 FND_FILE.PUT_LINE (FND_FILE.LOG, 'No Party Sites selected');
 END IF;

 IF (l_bsa_count = 0)
 THEN
 l_bad_params := TRUE;
 FND_FILE.PUT_LINE (FND_FILE.LOG, 'No BSA selected');
 ELSIF (l_bsa_count > 1)
 THEN
 l_bad_params := TRUE;
 FND_FILE.PUT_LINE (FND_FILE.LOG, 'More than one BSA selected');
 END IF;

 IF (l_bad_params)
 THEN
 FND_FILE.PUT_LINE (
 FND_FILE.LOG,
 'Bad query parameters for query "'
 || l_query_name
 || '" id: '
 || p_query_id
 || '. Ending program.');

 errbuf := 'Bad Query Parameters';

 retcode := 2;

 raise_application_error (-20000, 'Bad Query Parameters');
 END IF;

 IF l_has_data = 'Y'
 THEN
 FND_FILE.PUT_LINE (
 FND_FILE.LOG,
 'Data already saved for query "'
 || l_query_name
 || '" id: '
 || p_query_id
 || '. Ending program.');

 RUN_REPORT (l_query_id_c);
 ELSIF l_has_data = 'I'
 THEN
 FND_FILE.PUT_LINE (
 FND_FILE.LOG,
 'Program already running for "'
 || l_query_name
 || '" id: '
 || p_query_id
 || '. Ending program with error.');

 l_req_id := GET_REQ (l_query_id_c);

 IF (l_req_id = 0)
 THEN
 FND_FILE.PUT_LINE (
 FND_FILE.LOG,
 'Probable program failure. Please copy query and run again.');
 ELSE
 FND_FILE.PUT_LINE (
 FND_FILE.LOG,
 'Request Id '
 || l_req_id
 || ' currently running. Wait for it to finish to generate report data.');
 END IF;

 errbuf := 'Program running multiple instances';

 retcode := 2;

 raise_application_error (-20000,
 'Program running multiple instances');
 ELSE
 BEGIN
 INSERT INTO XXHA_ACCR_TRUEUP_CTRL (QUERY_ID,
 AS_OF_DATE,
 HAS_DATA,
 RUN_BY,
 REQUEST_ID)
 VALUES (p_query_id,
 SYSDATE,
 'I',
 FND_GLOBAL.USER_ID,
 FND_GLOBAL.CONC_REQUEST_ID);

 COMMIT;
 EXCEPTION
 WHEN DUP_VAL_ON_INDEX
 THEN
 FND_FILE.PUT_LINE (
 FND_FILE.LOG,
 'Program already running for "'
 || l_query_name
 || '" id: '
 || p_query_id
 || '. Ending program with error.');

 l_req_id := GET_REQ (l_query_id_c);

 IF (l_req_id = 0)
 THEN
 FND_FILE.PUT_LINE (
 FND_FILE.LOG,
 'Probable program failure. Please copy query and run again.');
 ELSE
 FND_FILE.PUT_LINE (
 FND_FILE.LOG,
 'Request Id '
 || l_req_id
 || ' currently running. Wait for it to finish to generate report data.');
 END IF;

 errbuf := 'Program running multiple instances';

 retcode := 2;
 RAISE;
 END;

 INSERT INTO XXHA_ACCR_TRUEUP_DATES (query_id,
 period_name,
 period_start_date,
 period_end_date,
 calendar_type,
 summary_date)
 SELECT query_id,
 period_name,
 period_start_date,
 period_end_date,
 calendar_type,
 summary_date
 FROM (SELECT qh.query_id,
 DECODE (
 qh.calendar_type,
 'Calendar', TO_CHAR (srpd.end_date, 'MON-YYYY'),
 gp.period_name)
 period_name,
 DECODE (qh.calendar_type,
 'Calendar', TRUNC (srpd.end_date, 'MM'),
 gp.start_date)
 period_start_date,
 DECODE (qh.calendar_type,
 'Calendar', LAST_DAY (srpd.end_date),
 gp.end_date)
 period_end_date,
 qh.calendar_type,
 srpd.end_date summary_date,
 ROW_NUMBER ()
 OVER (
 PARTITION BY query_id,
 DECODE (
 qh.calendar_type,
 'Calendar', LAST_DAY (
 srpd.end_date),
 gp.end_date)
 ORDER BY srpd.end_date DESC)
 dt_rnk
 FROM XXHA_SW_REBATE_PRODUCT_DATA srpd,
 gl_periods gp,
 xxha_accr_trueup_query_hdr qh
 WHERE query_id = p_query_id
 AND srpd.end_date BETWEEN qh.start_date
 AND qh.end_date
 AND srpd.end_date BETWEEN gp.start_date
 AND gp.end_date
 AND gp.period_set_name = 'HAE_GLOBAL_CAL'
 AND gp.period_type = '21') dts
 WHERE dt_rnk = 1;

 MERGE INTO XXHA_ACCR_TRUEUP_DATES A
 USING (SELECT query_id,
 ss_header_id,
 ss_date,
 period_name,
 period_end_date,
 period_start_date,
 calendar_type
 FROM (SELECT qh.query_id,
 ssh.ss_header_id,
 ssh.SS_DATE,
 DECODE (
 qh.CALENDAR_TYPE,
 'Calendar', TO_CHAR (ssh.SS_DATE,
 'MON-YYYY'),
 ssh.PERIOD_NAME)
 period_name,
 DECODE (
 qh.CALENDAR_TYPE,
 'Calendar', ssh.calendar_month_start,
 ssh.PERIOD_start_DATE)
 period_start_date,
 DECODE (
 qh.CALENDAR_TYPE,
 'Calendar', ssh.calendar_month_end,
 ssh.PERIOD_END_DATE)
 period_end_date,
 qh.CALENDAR_TYPE,
 ROW_NUMBER ()
 OVER (
 PARTITION BY query_id,
 DECODE (
 qh.CALENDAR_TYPE,
 'Calendar', ssh.calendar_month_end,
 ssh.PERIOD_END_DATE)
 ORDER BY ssh.ss_header_id DESC)
 dt_rnk
 FROM XXHA_IB_MACH_SS_HEADERS ssh,
 xxha_accr_trueup_query_hdr qh
 WHERE ssh.SS_DATE BETWEEN qh.START_DATE
 AND qh.END_DATE
 AND qh.query_id = p_query_id) dts
 WHERE dt_rnk = 1) B
 ON ( A.query_id = B.query_id
 AND a.period_end_date = b.period_end_date)
 WHEN NOT MATCHED
 THEN
 INSERT (QUERY_ID,
 SS_HEADER_ID,
 SS_DATE,
 PERIOD_NAME,
 PERIOD_END_DATE,
 PERIOD_START_DATE,
 CALENDAR_TYPE)
 VALUES (B.QUERY_ID,
 B.SS_HEADER_ID,
 B.SS_DATE,
 B.PERIOD_NAME,
 B.PERIOD_END_DATE,
 B.PERIOD_START_DATE,
 B.CALENDAR_TYPE)
 WHEN MATCHED
 THEN
 UPDATE SET A.SS_HEADER_ID = B.SS_HEADER_ID, A.SS_DATE = B.SS_DATE;

 COMMIT;

 UPDATE XXHA_ACCR_TRUEUP_DATES TD
 SET QUARTER_NUM =
 (SELECT LEAST (FLOOR ( (per_num - 1) / 3) + 1, 4) q_num
 FROM (SELECT query_id,
 period_end_date,
 ROW_NUMBER ()
 OVER (PARTITION BY query_id
 ORDER BY period_end_date)
 per_num
 FROM XXHA_ACCR_TRUEUP_DATES TD2
 WHERE td2.query_id = p_query_id) qn
 WHERE qn.query_id = TD.query_id
 AND qn.period_end_date = TD.period_end_date)
 WHERE td.query_id = p_query_id;

 COMMIT;

 INSERT INTO XXHA_ACCR_TRUEUP_AR_DATA (QUERY_ID,
 TRX_DATE,
 BILLED_MONTH,
 FISCAL_YEAR,
 FISCAL_QUARTER,
 FISCAL_PERIOD,
 FISCAL_PERIOD_NUM,
 BILL_TO_CUSTOMER_NUMBER,
 BILL_TO_CUSTOMER_NAME,
 BILL_TO_SITE_NUMBER,
 BILL_TO_CITY,
 BILL_TO_STATE,
 BILL_TO_POSTAL_CODE,
 BILL_TO_COUNTRY,
 BILL_TO_LOCATION,
 SHIP_TO_CUSTOMER_NUMBER,
 SHIP_TO_CUSTOMER_NAME,
 SHIP_TO_SITE_NUMBER,
 SHIP_TO_ADDRESS_1,
 SHIP_TO_ADDRESS_2,
 SHIP_TO_ADDRESS_3,
 SHIP_TO_ADDRESS_4,
 SHIP_TO_CITY,
 SHIP_TO_STATE,
 SHIP_TO_POSTAL_CODE,
 SHIP_TO_COUNTRY,
 SHIP_TO_LOCATION,
 OPERATING_UNIT,
 TRX_NUMBER,
 LINE_NUMBER,
 BILLING_QUANTITY,
 BILLING_QTY_EA,
 TOTAL_QTY,
 ORDER_NUMBER,
 PURCHASE_ORDER,
 ITEM,
 ITEM_DESCRIPTION,
 PRODUCT_LINE_CODE,
 PRODUCT_LINE_DESC,
 PRODUCT_TYPE_CODE,
 PRODUCT_TYPE_DESC,
 PRODUCT_SUB_TYPE_CODE,
 PRODUCT_SUB_TYPE_DESC,
 PLATFORM_CODE,
 PLATFORM_DESC,
 PRICE,
 PRICE_EACH,
 OVERRIDE_QUANTITY,
 UNIT_OF_MEASURE,
 REVENUE_AMOUNT,
 NEW_SITE_EXCLUDE)
 SELECT qh.query_id,
 ra.trx_date,
 CASE
 WHEN qh.calendar_type = 'Calendar'
 THEN
 TO_CHAR (ra.trx_date, 'MON-YYYY')
 ELSE
 gp.period_name
 END
 BILLED_MONTH,
 gp.PERIOD_YEAR FISCAL_YEAR,
 gp.period_year || ' Q' || gp.quarter_num fiscal_quarter,
 gp.period_name fiscal_period,
 gp.period_num fiscal_period_num,
 hc_bill.account_number bill_to_customer_number,
 hp_bill.party_name bill_to_customer_name,
 hps_bill.party_site_number bill_to_site_number,
 hl_bill.city bill_to_city,
 hl_bill.state bill_to_state,
 hl_bill.postal_code bill_to_postal_code,
 hl_bill.country bill_to_country,
 hcsua_bill.location bill_to_location,
 hc_ship.account_number ship_to_customer_number,
 hp_ship.party_name ship_to_customer_name,
 hps_ship.party_site_number ship_to_site_number,
 hl_ship.address1 ship_to_address_1,
 hl_ship.address2 ship_to_address_2,
 hl_ship.address3 ship_to_address_3,
 hl_ship.address4 ship_to_address_4,
 hl_ship.city ship_to_city,
 hl_ship.state ship_to_state,
 hl_ship.postal_code ship_to_postal_code,
 hl_ship.country ship_to_country,
 hcsua_ship.location ship_to_location,
 hou.name operating_unit,
 ra.trx_number,
 rl.line_number,
 NVL (rl.quantity_credited, rl.quantity_invoiced)
 BILLING_QUANTITY,
 decode(msib.segment1,'0625B-00',NVL (rl.quantity_credited, rl.quantity_invoiced)
 * (INV_CONVERT.INV_UM_CONVERT (rl.inventory_item_id,
 rl.uom_code,
 'Ea')))
 billing_qty_ea,
 decode(msib.segment1,'0625B-00',NVL (
 srb.override_billing_quantity
 * (INV_CONVERT.INV_UM_CONVERT (rl.inventory_item_id,
 rl.uom_code,
 'Ea')),
 ( NVL (rl.quantity_credited, rl.quantity_invoiced)
 * INV_CONVERT.INV_UM_CONVERT (rl.inventory_item_id,
 rl.uom_code,
 'Ea'))))
 total_qty,
 CASE
 WHEN ra.interface_header_context = 'ORDER ENTRY'
 THEN
 RA.CT_REFERENCE
 END
 ORDER_NUMBER,
 RA.purchase_order,
 MSIB.SEGMENT1 ITEM,
 msib.description ITEM_DESCRIPTION,
 mc.segment1 product_line_code,
 REGEXP_REPLACE (mc.DESCRIPTION, '^([^.]+)\..+$', '\1')
 AS product_line_desc,
 mc.segment2 product_type_code,
 REGEXP_REPLACE (mc.DESCRIPTION,
 '^[^.]+\.([^.]+)\..+$',
 '\1')
 AS product_type_desc,
 mc.segment3 product_sub_type_code,
 REGEXP_REPLACE (mc.DESCRIPTION,
 '^[^.]+\.[^.]+\.([^.]+)\..+$',
 '\1')
 AS product_sub_type_desc,
 REGEXP_REPLACE (mc.DESCRIPTION,
 '^[^.]+\.[^.]+\.[^.]+\.(.+)$',
 '\1')
 AS platform,
 mc.segment4 platform_code,
 rl.UNIT_SELLING_PRICE PRICE,
 rl.UNIT_SELLING_PRICE
 / (INV_CONVERT.INV_UM_CONVERT (rl.inventory_item_id,
 rl.uom_code,
 'Ea'))
 PRICE_EACH,
 decode(msib.segment1,'0625B-00',srb.override_billing_quantity
 * (INV_CONVERT.INV_UM_CONVERT (rl.inventory_item_id,
 rl.uom_code,
 'Ea')))
 override_quantity,
 muom.description unit_of_measure,
 rl.revenue_amount,
 case when exists (select 0 from XXHA_ACCR_TRUEUP_QUERY_SITE tqs
 WHERE qh.query_id = tqs.query_id
 AND tqs.active_flag = 'Y'
 AND hcasa_ship.party_site_id = tqs.party_site_id
 AND tqs.start_date is not null
 and tqs.end_date is not null
 and trunc(ra.trx_date) between tqs.start_date and tqs.end_date) then 'Y' end new_site_exclude
 FROM xxha_accr_trueup_query_hdr qh,
 ra_customer_trx_all ra,
 HR_OPERATING_UNITS hou,
 ra_customer_trx_lines_all rl,
 mtl_system_items_b msib,
 ra_cust_trx_types_all rt,
 hz_cust_accounts hc_bill,
 hz_parties hp_bill,
 hz_cust_acct_sites_all hcasa_bill,
 hz_cust_site_uses_all hcsua_bill,
 hz_party_sites hps_bill,
 hz_locations hl_bill,
 hz_cust_accounts hc_ship,
 hz_parties hp_ship,
 hz_cust_acct_sites_all hcasa_ship,
 hz_cust_site_uses_all hcsua_ship,
 hz_party_sites hps_ship,
 hz_locations hl_ship,
 mtl_units_of_measure muom,
 mtl_item_categories mic,
 mtl_categories mc,
 mtl_categories_tl mct,
 ( SELECT customer_trx_line_id,
 SUM (override_billing_quantity)
 override_billing_quantity
 FROM XXHA_SW_REBATE_BILL_DATA
 GROUP BY customer_trx_line_id) srb,
 gl_periods gp
 WHERE 1 = 1
 AND ra.customer_trx_id = rl.customer_trx_id
 AND hou.organization_id = ra.org_id
 AND ra.org_id = rt.org_id
 AND ra.org_id = 102
 AND ra.complete_flag = 'Y'
 AND ra.cust_trx_type_id = rt.cust_trx_type_id
 AND EXISTS
 (SELECT 0
 FROM xxha_accr_trueup_query_cust qc
 WHERE ra.BILL_TO_CUSTOMER_ID =
 qc.cust_account_id
 AND qc.active_flag = 'Y'
 AND qc.query_id = qh.query_id)
 AND hcsua_bill.site_use_id = ra.bill_to_site_use_id
 AND hcasa_bill.cust_acct_site_id =
 hcsua_bill.cust_acct_site_id
 AND hcasa_bill.cust_account_id = hc_bill.cust_account_id
 AND hp_bill.party_id = hc_bill.party_id
 AND hps_bill.party_site_id = hcasa_bill.party_site_id
 AND hl_bill.location_id = hps_bill.location_id
 AND hcsua_ship.site_use_id(+) = ra.ship_to_site_use_id
 AND hcasa_ship.cust_acct_site_id(+) =
 hcsua_ship.cust_acct_site_id
 AND hcasa_ship.cust_account_id =
 hc_ship.cust_account_id(+)
 AND hp_ship.party_id(+) = hc_ship.party_id
 AND hps_ship.party_site_id(+) = hcasa_ship.party_site_id
 AND hl_ship.location_id(+) = hps_ship.location_id
 AND rl.uom_code = muom.uom_code
 AND rl.inventory_item_id = msib.inventory_item_id
 AND msib.organization_id = 103
 AND msib.segment1 in ('0625B-00','ADJ-0625B-00')
 AND msib.organization_id = mic.organization_id(+)
 AND msib.inventory_item_id = mic.inventory_item_id(+)
 AND mic.CATEGORY_SET_ID(+) = 1
 AND mic.category_id = mc.category_id(+)
 AND mc.category_id = mct.category_id(+)
 AND mct.LANGUAGE(+) = 'US'
 AND srb.customer_trx_line_id(+) = rl.customer_trx_line_id
 AND gp.period_set_name = 'HAE_GLOBAL_CAL'
 AND gp.period_type = '21'
 AND ra.trx_date BETWEEN gp.start_date AND gp.end_date
 AND RA.TRX_DATE BETWEEN TRUNC (qh.start_date)
 AND TRUNC (
 LEAST (qh.end_date, SYSDATE))
 AND qh.query_id = p_query_id;

 COMMIT;

 INSERT INTO XXHA_ACCR_TRUEUP_IB_DATA (QUERY_ID,
 SS_DATE,
 SNAPSHOT_MONTH,
 OPERATING_UNIT,
 INSTANCE_ID,
 INSTANCE_NUMBER,
 PARTY_NUMBER,
 PARTY_NAME,
 CUSTOMER_NUMBER,
 CUSTOMER_NAME,
 ITEM_NUMBER,
 SERIAL_NUMBER,
 STATUS,
 INSTANCE_TYPE_CODE,
 INSTANCE_TYPE,
 LOCATION_TYPE_CODE,
 LOCATION_ID,
 INSTALL_DATE,
 CREATION_DATE,
 CURRENT_LOCATION_PARTY_STATUS,
 CURRENT_LOCATION_PARTY_NAME,
 CURRENT_LOCATION_PARTY_NUMBER,
 CURRENT_LOCATION_CUST_NUMBER,
 location,
 ADDRESS_1,
 ADDRESS_2,
 ADDRESS_3,
 ADDRESS_4,
 CITY,
 STATE,
 POSTAL_CODE,
 COUNTRY,
 REGION,
 PARTY_SITE_NUMBER,
 MACHINE_GROUPING,
 EXTERNAL_REFERENCE,
 PM_INTERVAL__MO1,
 NEXT_PM_DATE__D2,
 LAST_PM_DATE__D3,
 SOFTWARE_VERSION,
 LAST_UPGRADED_H5,
 LAST_FREE_SERVICE_DATE,
 SHIPPED_DATE,
 BILL_TO_SITE_NUM,
 SHIP_TO_SITE_NUM,
 SHIP_TO_REGION,
 ACCOUNTING_CLASS_CODE,
 PRODUCT_LINE,
 PRODUCT_TYPE,
 PRODUCT_SUB_TYPE,
 PLATFORM,
 QUARTER_NUM,
 NEW_SITE_EXCLUDE)
 SELECT atd.query_ID,
 atd.SS_DATE,
 atd.period_name snapshot_month,
 mss.OPERATING_UNIT,
 mss.INSTANCE_ID,
 mss.INSTANCE_NUMBER,
 mss.PARTY_NUMBER,
 mss.PARTY_NAME,
 mss.CUSTOMER_NUMBER,
 mss.CUSTOMER_NAME,
 mss.ITEM_NUMBER,
 mss.SERIAL_NUMBER,
 mss.STATUS,
 mss.INSTANCE_TYPE_CODE,
 mss.INSTANCE_TYPE,
 mss.LOCATION_TYPE_CODE,
 mss.LOCATION_ID,
 mss.INSTALL_DATE,
 mss.CREATION_DATE,
 mss.CURRENT_LOCATION_PARTY_STATUS,
 mss.CURRENT_LOCATION_PARTY_NAME,
 mss.CURRENT_LOCATION_PARTY_NUMBER,
 mss.CURRENT_LOCATION_CUST_NUMBER,
 stl.location,
 mss.ADDRESS_1,
 mss.ADDRESS_2,
 mss.ADDRESS_3,
 mss.ADDRESS_4,
 mss.CITY,
 mss.STATE,
 mss.POSTAL_CODE,
 mss.COUNTRY,
 mss.REGION,
 mss.PARTY_SITE_NUMBER,
 mss.MACHINE_GROUPING,
 mss.EXTERNAL_REFERENCE,
 mss.PM_INTERVAL__MO1,
 mss.NEXT_PM_DATE__D2,
 mss.LAST_PM_DATE__D3,
 mss.SOFTWARE_VERSION,
 mss.LAST_UPGRADED_H5,
 mss.LAST_FREE_SERVICE_DATE,
 mss.SHIPPED_DATE,
 mss.BILL_TO_SITE_NUM,
 mss.SHIP_TO_SITE_NUM,
 mss.SHIP_TO_REGION,
 mss.ACCOUNTING_CLASS_CODE,
 mss.PRODUCT_LINE,
 mss.PRODUCT_TYPE,
 mss.PRODUCT_SUB_TYPE,
 mss.PLATFORM,
 atd.quarter_num,
 case when EXISTS
 (SELECT 0
 FROM XXHA_ACCR_TRUEUP_QUERY_SITE tqs
 WHERE atd.query_id = tqs.query_id
 AND tqs.active_flag = 'Y'
 AND mss.location_id = tqs.party_site_id
 AND tqs.start_date is not null
 and tqs.end_date is not null
 and trunc(atd.SS_DATE) between tqs.start_date and tqs.end_date) then 'Y' end new_site_exclude
 FROM XXHA_ACCR_TRUEUP_DATES atd,
 (SELECT hcasa.party_site_id,
 HCSUA.location,
 ROW_NUMBER ()
 OVER (PARTITION BY party_site_id
 ORDER BY
 HCSUA.site_use_code DESC,
 HCSUA.status,
 HCSUA.primary_flag DESC,
 hcsua.org_id,
 hcsua.site_use_id DESC)
 loc_rnk
 FROM APPS.HZ_CUST_ACCT_SITES_ALL HCASA,
 apps.hz_cust_site_uses_all hcsua
 WHERE hcsua.cust_acct_site_id =
 hcasa.cust_acct_site_id
 AND hcsua.site_use_code IN ('SHIP_TO',
 'INSTALL_AT')
 AND HCSUA.ORG_ID = 102) stl,
 XXHA_IB_MACHINE_SS mss
 WHERE atd.SS_HEADER_ID = mss.SS_HEADER_ID
 AND EXISTS
 (SELECT 0
 FROM XXHA_ACCR_TRUEUP_QUERY_SITE tqs
 WHERE atd.query_id = tqs.query_id
 AND tqs.active_flag = 'Y'
 AND mss.location_id = tqs.party_site_id)
 AND stl.loc_rnk = 1
 AND mss.location_id = stl.party_site_id
 AND mss.LOCATION_TYPE_CODE = 'HZ_PARTY_SITES'
 AND mss.PLATF_SEG IN ('PCS', 'NexSys', 'PCS2')
 AND mss.SERIAL_NUMBER IS NOT NULL
 AND atd.query_id = p_query_id;

 COMMIT;

 INSERT INTO XXHA_ACCR_TRUEUP_PD (QUERY_ID,
 END_DATE,
 PERIOD_NAME,
 PERIOD_END_DATE,
 PARTY_NAME,
 ACCOUNT_NUMBER,
 PARTY_SITE_NUMBER,
 ADDRESS_1,
 ADDRESS_2,
 ADDRESS_3,
 ADDRESS_4,
 CITY,
 STATE,
 POSTAL_CODE,
 COUNTRY,
 PROD_LOCATION,
 NO_OF_DEVICES,
 OVERRIDE_DEVICES,
 TOTAL_DEVICES,
 NEW_SITE_EXCLUDE)
 SELECT dts.query_id,
 x.END_DATE,
 dts.period_name,
 dts.period_end_date,
 hp.party_name,
 hca.account_number,
 hps.party_site_number,
 hl.address1,
 hl.address2,
 hl.address3,
 hl.address4,
 hl.city,
 hl.state,
 hl.postal_code,
 hl.country,
 hcsua_ship.location prod_location,
 SUM (x.no_of_devices) NO_OF_DEVICES,
 NVL2 (SUM (x.override_noofdevices),
 SUM (NVL (x.override_noofdevices, x.no_of_devices)),
 NULL)
 override_devices,
 SUM (NVL (x.override_noofdevices, x.no_of_devices))
 total_devices,
 case when EXISTS
 (SELECT 0
 FROM XXHA_ACCR_TRUEUP_QUERY_SITE tqs
 WHERE dts.query_id = tqs.query_id
 AND tqs.active_flag = 'Y'
 AND hcasa_ship.party_site_id = tqs.party_site_id
 AND tqs.start_date is not null
 and tqs.end_date is not null
 and trunc(x.END_DATE) between tqs.start_date and tqs.end_date) then 'Y' end new_site_exclude
 FROM XXHA_SW_REBATE_PRODUCT_DATA x,
 XXHA_ACCR_TRUEUP_DATES dts,
 HZ_PARTIES HP,
 hz_cust_site_uses_all hcsua_ship,
 hz_cust_acct_sites_all hcasa_ship,
 hz_cust_accounts hca,
 hz_party_sites hps,
 hz_locations hl
 WHERE 1 = 1
 AND x.END_DATE = dts.SUMMARY_DATE --Added by 26-April-2018
 AND X.PARTY_ID = HP.PARTY_ID
 AND X.ship_to_site_use_id = hcsua_ship.site_use_id
 AND hcsua_ship.site_use_code IN ('SHIP_TO', 'INSTALL_AT')
 AND hcsua_ship.cust_acct_site_id =
 hcasa_ship.cust_acct_site_id
 AND hcasa_ship.cust_account_id = hca.cust_account_id
 AND hcasa_ship.party_site_id = hps.party_site_id
 AND hl.location_id = hps.location_id
 AND EXISTS
 (SELECT 0
 FROM XXHA_ACCR_TRUEUP_QUERY_SITE tqs
 WHERE tqs.query_id = dts.query_id
 AND hcasa_ship.party_site_id =
 tqs.party_site_id
 AND tqs.active_flag = 'Y')
 AND dts.query_id = p_query_id
 GROUP BY dts.query_id,
 x.END_DATE,
 dts.period_name,
 dts.period_end_date,
 hp.party_name,
 hca.account_number,
 hps.party_site_number,
 hl.address1,
 hl.address2,
 hl.address3,
 hl.address4,
 hl.city,
 hl.state,
 hl.postal_code,
 hl.country,
 hcsua_ship.location,
 case when EXISTS
 (SELECT 0
 FROM XXHA_ACCR_TRUEUP_QUERY_SITE tqs
 WHERE dts.query_id = tqs.query_id
 AND tqs.active_flag = 'Y'
 AND hcasa_ship.party_site_id = tqs.party_site_id
 AND tqs.start_date is not null
 and tqs.end_date is not null
 and trunc(x.END_DATE) between tqs.start_date and tqs.end_date) then 'Y' end;

 COMMIT;

 INSERT INTO XXHA_ACCR_TRUEUP_SUM (QUERY_ID,
 CUSTOMER_NUMBER,
 CUSTOMER_NAME,
 BSA_NUMBER,
 NO_OF_UTILIZATION_DAYS,
 NET_NUMBER_OF_DAYS,
 TARGET_UTILIZATION)
 SELECT query_id,
 customer_number,
 customer_name,
 bsa_number,
 no_of_utilization_days,
 net_number_of_days,
 target_utilization
 FROM (SELECT qh.query_id,
 hca.account_number customer_number,
 hp.party_name customer_name,
 b.order_number bsa_number,
 NVL (TO_NUMBER (PL.ATTRIBUTE13), 260)
 no_of_utilization_days,
 DECODE (
 qh.calendar_type,
 /*For Calendar, divide utilization days
 evenly between whole calendar months,
 irrespective of month length.*/
 'Calendar', MONTHS_BETWEEN (
 TRUNC (
 LEAST (qh.end_date,
 SYSDATE))
 + 1,
 qh.start_date)
 / 12,
 /*For Fiscal, divide utilization days
 according to 4,4,5 pattern*/
 ( TRUNC (LEAST (qh.end_date, SYSDATE))
 - TRUNC (qh.start_date)
 + 1)
 / 364)
 * NVL (TO_NUMBER (PL.ATTRIBUTE13), 260)
 net_number_of_days,
 TO_NUMBER (PL.ATTRIBUTE12) target_utilization,
 ROW_NUMBER ()
 OVER (PARTITION BY qh.query_id
 ORDER BY PL.START_DATE_ACTIVE DESC)
 pl_rnk
 FROM xxha_accr_trueup_query_hdr qh,
 xxha_accr_trueup_bsa qb,
 OE_BLANKET_HEADERS_ALL B,
 OE_BLANKET_LINES_ALL BL,
 QP_LIST_LINES_V PL,
 HZ_CUST_ACCOUNTS_ALL HCA,
 hz_parties hp
 WHERE 1 = 1
 AND qh.query_id = qb.query_id
 AND qb.active_flag = 'Y'
 AND qb.header_id = b.header_id
 AND B.HEADER_ID = BL.HEADER_ID
 AND BL.PRICE_LIST_ID = PL.LIST_HEADER_ID
 AND BL.INVENTORY_ITEM_ID = PL.PRODUCT_ATTR_VALUE
 AND PL.PRODUCT_ATTRIBUTE_CONTEXT = 'ITEM'
 AND BL.INVENTORY_ITEM_ID = 2296 -- 0625B-00
 AND B.sold_to_org_id = HCA.cust_account_id
 AND hca.party_id = hp.party_id
 AND TRUNC (PL.START_DATE_ACTIVE) <=
 TRUNC (LEAST (qh.end_date, SYSDATE))
 AND TRUNC (NVL (PL.END_DATE_ACTIVE, qh.end_date)) >=
 TRUNC (qh.start_date)
 --AND PL.ATTRIBUTE12 IS NOT NULL
 AND B.org_id = 102
 AND qh.query_id = p_query_id) tuc
 WHERE pl_rnk = 1;

 COMMIT;

 UPDATE XXHA_ACCR_TRUEUP_SUM ts
 SET (net_bowls, ACTUAL_INVOICED, net_bowls_nsx, ACTUAL_INVOICED_NSX) =
 (SELECT SUM (total_qty) net_bowls,
 SUM (decode(ITEM,'ADJ-0625B-00',REVENUE_AMOUNT,0)) actual_inv,
 SUM (decode(NEW_SITE_EXCLUDE,'Y',0,total_qty)) net_bowls_nsx,
 SUM (case when NEW_SITE_EXCLUDE = 'Y' then 0 when ITEM = 'ADJ-0625B-00' then REVENUE_AMOUNT else 0 end) actual_inv_nsx
 FROM XXHA_ACCR_TRUEUP_AR_DATA ad
 WHERE ad.query_id = ts.query_id)
 WHERE ts.query_id = p_query_id;

 COMMIT;

 UPDATE XXHA_ACCR_TRUEUP_SUM ts
 SET (AVG_DEVICES, AVG_DEVICES_NSX) =
 (SELECT SUM (total_devices)
 / COUNT (DISTINCT td.period_end_date)
 avg_devices,
 SUM (greatest(total_devices-decode(NEW_SITE_EXCLUDE,'Y',l_max_device_excl,0),0))
 / COUNT (DISTINCT td.period_end_date)
 avg_devices_nsx 
 FROM XXHA_ACCR_TRUEUP_DATES TD, XXHA_ACCR_TRUEUP_PD pd
 WHERE TD.query_id = pd.query_id(+)
 AND td.period_end_date = pd.period_end_date(+)
 AND td.query_id = ts.query_id)
 WHERE ts.query_id = p_query_id;

 COMMIT;

 UPDATE XXHA_ACCR_TRUEUP_SUM ts
 SET actual_utilization =
 ROUND (net_bowls / avg_devices / net_number_of_days, 2),
 actual_utilization_nsx = case when NVL (avg_devices_nsx, 0) <> 0 then
 ROUND (net_bowls_nsx / case when NVL (avg_devices_nsx, 0) = 0 then 1 else avg_devices_nsx end / net_number_of_days, 2) end
 WHERE ts.query_id = p_query_id AND NVL (avg_devices, 0) <> 0;

 COMMIT;

 INSERT INTO XXHA_ACCR_TRUEUP_PRICE (QUERY_ID,
 MIN_VAL,
 MAX_VAL,
 UTILIZATION,
 PRICE,
 BOWL_PRICE)
 SELECT query_id,
 CASE tag_rnk WHEN 1 THEN NULL ELSE lookup_tag END min_val,
 next_val max_val,
 CASE
 WHEN tag_rnk = 1 AND next_val IS NULL
 THEN
 'Fixed'
 WHEN tag_rnk = 1
 THEN
 '< ' || TO_CHAR (next_val, 'FM999.00')
 WHEN next_val IS NULL
 THEN
 '>= ' || TO_CHAR (lookup_tag, 'FM999.00')
 ELSE
 TO_CHAR (lookup_tag, 'FM999.00')
 || ' to '
 || TO_CHAR (next_val - .01, 'FM999.00')
 END
 utilization,
 price,
 bowl_price
 FROM (SELECT qh.query_id,
 flt.meaning cust_lookup,
 flv.lookup_code,
 TO_NUMBER (tag) lookup_tag,
 ROW_NUMBER ()
 OVER (PARTITION BY flv.lookup_type
 ORDER BY TO_NUMBER (tag))
 tag_rnk,
 LEAD (
 TO_NUMBER (tag))
 OVER (PARTITION BY flv.lookup_type
 ORDER BY TO_NUMBER (tag))
 next_val,
 TO_NUMBER (regexp_substr(flv.description,'^(-?\d*\.?\d*)$',1,1,NULL,1)) price,
 TO_NUMBER (regexp_substr(flv.meaning,'^(-?\d*\.?\d*)$',1,1,NULL,1)) bowl_price
 FROM xxha_accr_trueup_query_hdr qh,
 XXHA_ACCR_TRUEUP_SUM ts,
 fnd_lookup_types_tl flt,
 fnd_lookup_values flv
 WHERE qh.query_id = ts.query_id
 AND flt.lookup_type = flv.lookup_type
 AND flv.language = 'US'
 AND flt.language = 'US'
 AND flt.meaning =
 'HAE_CUST_ACCT|||' || ts.customer_number
 AND TRUNC (LEAST (qh.end_date, SYSDATE)) BETWEEN flv.start_date_active
 AND NVL (
 flv.end_date_active,
 qh.end_date)
 AND qh.query_id = p_query_id);

 COMMIT;
 
 UPDATE XXHA_ACCR_TRUEUP_SUM ts
 SET ACTUAL_UTIL_CHARGE = (SELECT tp.price
 FROM XXHA_ACCR_TRUEUP_PRICE tp
 WHERE tp.query_id = ts.query_id
 AND ( tp.min_val <= ts.actual_utilization
 OR tp.min_val IS NULL)
 AND ( tp.max_val > ts.actual_utilization
 OR tp.max_val IS NULL)),
 TARGET_UTIL_CHARGE = (SELECT tp.price
 FROM XXHA_ACCR_TRUEUP_PRICE tp
 WHERE tp.query_id = ts.query_id
 AND ( tp.min_val <= ts.target_utilization
 OR tp.min_val IS NULL)
 AND ( tp.max_val > ts.target_utilization
 OR tp.max_val IS NULL)),
 ACTUAL_UTIL_CHARGE_NSX = (SELECT tp.price
 FROM XXHA_ACCR_TRUEUP_PRICE tp
 WHERE tp.query_id = ts.query_id
 AND ( tp.min_val <= ts.actual_utilization_nsx
 OR tp.min_val IS NULL)
 AND ( tp.max_val > ts.actual_utilization_nsx
 OR tp.max_val IS NULL))
 WHERE ts.query_id = p_query_id;

 UPDATE XXHA_ACCR_TRUEUP_SUM ts
 SET PRICE_AT_ACTUAL_UTIL = net_bowls * ACTUAL_UTIL_CHARGE,
 PRICE_AT_TARGET_UTIL = net_bowls * TARGET_UTIL_CHARGE,
 PRICE_AT_ACTUAL_UTIL_NSX = net_bowls_nsx * ACTUAL_UTIL_CHARGE_NSX,
 PRICE_AT_TARGET_UTIL_NSX = net_bowls_nsx * TARGET_UTIL_CHARGE
 WHERE query_id = p_query_id;

 COMMIT;

 UPDATE XXHA_ACCR_TRUEUP_SUM ts
 SET TRUE_UP_AMT = nullif(nvl(PRICE_AT_ACTUAL_UTIL,0) - nvl(PRICE_AT_TARGET_UTIL,0),0),
 TRUE_UP_AMT_NSX = nullif(nvl(PRICE_AT_ACTUAL_UTIL_NSX,0) - nvl(PRICE_AT_TARGET_UTIL_NSX,0),0)
 WHERE ts.query_id = p_query_id;

 COMMIT;

 INSERT INTO XXHA_ACCR_TRUEUP_PER_SUM (QUERY_ID,
 YEAR_START_DATE,
 PERIOD_LEVEL,
 PERIOD_NAME,
 PERIOD_START_DATE,
 PERIOD_END_DATE,
 CALENDAR_TYPE,
 NET_NUMBER_OF_DAYS)
 WITH fiscal_year
 AS (SELECT query_id,
 gp.period_name,
 gp.start_date period_start_date,
 gp.end_date period_end_date,
 qh.calendar_type,
 qh.start_date q_start_date,
 TRUNC (LEAST (qh.end_date, SYSDATE)) q_end_date,
 GREATEST (gp.start_date, qh.start_date)
 net_start_date,
 LEAST (gp.end_date, qh.end_date, TRUNC (SYSDATE))
 net_end_date,
 period_year
 FROM xxha_accr_trueup_query_hdr qh, gl_periods gp
 WHERE calendar_type = 'Fiscal'
 AND query_id = p_query_id
 AND gp.period_set_name = 'HAE_GLOBAL_CAL'
 AND gp.start_date <=
 TRUNC (LEAST (qh.end_date, SYSDATE))
 AND gp.end_date >= qh.start_date
 AND period_type = 'Year'),
 per_list
 AS (SELECT query_id,
 4 period_level,
 'YTD ' || period_name period_name,
 period_start_date year_start_date,
 period_start_date,
 period_end_date,
 calendar_type,
 GREATEST (period_start_date, q_start_date)
 net_start_date,
 LEAST (period_end_date, q_end_date) net_end_date
 FROM fiscal_year fy
 UNION ALL
 SELECT query_id,
 1 period_level,
 gp.period_name,
 fy.period_start_date year_start_date,
 gp.start_date period_start_date,
 gp.end_date period_end_date,
 calendar_type,
 CASE
 WHEN q_start_date <= gp.end_date
 AND q_end_date >= gp.start_date
 THEN
 GREATEST (gp.start_date, q_start_date)
 END
 net_start_date,
 CASE
 WHEN q_start_date <= gp.end_date
 AND q_end_date >= gp.start_date
 THEN
 LEAST (gp.end_date, q_end_date)
 END
 net_end_date
 FROM fiscal_year fy, gl_periods gp
 WHERE period_type = '21'
 AND gp.period_set_name = 'HAE_GLOBAL_CAL'
 AND gp.period_year = fy.period_year
 UNION ALL
 SELECT query_id,
 2 period_level,
 'QTD Q'
 || gp.quarter_num
 || '-'
 || TO_CHAR (MOD (gp.period_year, 100), 'FM00')
 period_name,
 fy.period_start_date year_start_date,
 MIN (gp.start_date) period_start_date,
 MAX (gp.end_date) period_end_date,
 calendar_type,
 MIN (
 CASE
 WHEN q_start_date <= gp.end_date
 AND q_end_date >= gp.start_date
 THEN
 GREATEST (gp.start_date, q_start_date)
 END)
 net_start_date,
 MAX (
 CASE
 WHEN q_start_date <= gp.end_date
 AND q_end_date >= gp.start_date
 THEN
 LEAST (gp.end_date, q_end_date)
 END)
 net_end_date
 FROM fiscal_year fy, gl_periods gp
 WHERE period_type = '21'
 AND gp.period_set_name = 'HAE_GLOBAL_CAL'
 AND gp.period_year = fy.period_year
 GROUP BY query_id,
 fy.period_start_date,
 calendar_type,
 gp.quarter_num,
 gp.period_year
 UNION ALL
 SELECT query_id,
 3 period_level,
 'YTD Q'
 || gp.quarter_num
 || '-'
 || TO_CHAR (MOD (gp.period_year, 100), 'FM00')
 period_name,
 fy.period_start_date year_start_date,
 MIN (
 CASE
 WHEN q_end_date >= gp.start_date
 THEN
 fy.period_start_date
 ELSE
 gp.start_date
 END)
 period_start_date,
 MAX (gp.end_date) period_end_date,
 calendar_type,
 GREATEST (fy.period_start_date, q_start_date)
 net_start_date,
 MAX (
 CASE
 WHEN q_start_date <= gp.end_date
 AND q_end_date >= gp.start_date
 THEN
 LEAST (gp.end_date, q_end_date)
 END)
 net_end_date
 FROM fiscal_year fy, gl_periods gp
 WHERE period_type = '21'
 AND gp.period_set_name = 'HAE_GLOBAL_CAL'
 AND gp.period_year = fy.period_year
 GROUP BY query_id,
 fy.period_start_date,
 q_start_date,
 calendar_type,
 gp.quarter_num,
 gp.period_year)
 SELECT pl.query_id,
 year_start_date,
 period_level,
 period_name,
 period_start_date,
 period_end_date,
 calendar_type,
 (net_end_date - net_start_date + 1)
 / 364
 * NO_OF_UTILIZATION_DAYS
 NET_NUMBER_OF_DAYS
 FROM per_list pl, XXHA_ACCR_TRUEUP_SUM ts
 WHERE pl.query_id = ts.query_id;

 INSERT INTO XXHA_ACCR_TRUEUP_PER_SUM (QUERY_ID,
 YEAR_START_DATE,
 PERIOD_LEVEL,
 PERIOD_NAME,
 PERIOD_START_DATE,
 PERIOD_END_DATE,
 CALENDAR_TYPE,
 NET_NUMBER_OF_DAYS)
 WITH cal_year (query_id,
 calendar_type,
 q_start_date,
 q_end_date,
 period_start_date,
 period_end_date,
 year_type,
 NO_OF_UTILIZATION_DAYS,
 NET_NUMBER_OF_DAYS)
 AS (SELECT qh.query_id,
 qh.calendar_type,
 qh.start_date q_start_date,
 TRUNC (LEAST (qh.end_date, SYSDATE)) q_end_date,
 TRUNC (qh.start_date, 'MM') period_start_date,
 ADD_MONTHS (TRUNC (qh.start_date, 'MM'), 12) - 1
 period_end_date,
 CASE
 WHEN TRUNC (qh.start_date, 'MM') =
 TRUNC (qh.start_date, 'YYYY')
 THEN
 'CY'
 ELSE
 'YE'
 END
 year_type,
 ts.NO_OF_UTILIZATION_DAYS,
 MONTHS_BETWEEN (
 LEAST (
 TRUNC (SYSDATE) + 1,
 qh.end_date + 1,
 ADD_MONTHS (TRUNC (qh.start_date, 'MM'),
 12)),
 qh.start_date)
 / 12
 * ts.NO_OF_UTILIZATION_DAYS
 NET_NUMBER_OF_DAYS
 FROM xxha_accr_trueup_query_hdr qh,
 XXHA_ACCR_TRUEUP_SUM ts
 WHERE qh.calendar_type = 'Calendar'
 AND qh.query_id = p_query_id
 AND qh.query_id = ts.query_id
 UNION ALL
 SELECT query_id,
 calendar_type,
 q_start_date,
 q_end_date,
 ADD_MONTHS (period_start_date, 12)
 period_start_date,
 ADD_MONTHS (period_end_date, 12) period_end_date,
 year_type,
 NO_OF_UTILIZATION_DAYS,
 MONTHS_BETWEEN (
 LEAST (q_end_date,
 ADD_MONTHS (period_end_date, 12))
 + 1,
 ADD_MONTHS (period_start_date, 12))
 / 12
 * NO_OF_UTILIZATION_DAYS
 NET_NUMBER_OF_DAYS
 FROM cal_year
 WHERE ADD_MONTHS (period_start_date, 12) <= q_end_date),
 cal_mth (query_id,
 calendar_type,
 q_start_date,
 q_end_date,
 year_start_date,
 year_end_date,
 period_start_date,
 period_end_date,
 NO_OF_UTILIZATION_DAYS,
 NET_NUMBER_OF_DAYS)
 AS (SELECT cy.query_id,
 calendar_type,
 q_start_date,
 q_end_date,
 period_start_date year_start_date,
 period_end_date year_end_date,
 period_start_date,
 LAST_DAY (period_start_date) period_end_date,
 NO_OF_UTILIZATION_DAYS,
 MONTHS_BETWEEN (
 LEAST (LAST_DAY (period_start_date),
 q_end_date)
 + 1,
 q_start_date)
 / 12
 * NO_OF_UTILIZATION_DAYS
 NET_NUMBER_OF_DAYS
 FROM cal_year cy
 UNION ALL
 SELECT query_id,
 calendar_type,
 q_start_date,
 q_end_date,
 year_start_date,
 year_end_date,
 ADD_MONTHS (period_start_date, 1)
 period_start_date,
 LAST_DAY (ADD_MONTHS (period_start_date, 1))
 period_end_date,
 NO_OF_UTILIZATION_DAYS,
 CASE
 WHEN q_end_date > period_end_date
 THEN
 MONTHS_BETWEEN (
 LEAST (
 LAST_DAY (
 ADD_MONTHS (period_start_date,
 1)),
 q_end_date)
 + 1,
 ADD_MONTHS (period_start_date, 1))
 / 12
 * NO_OF_UTILIZATION_DAYS
 END
 NET_NUMBER_OF_DAYS
 FROM cal_mth
 WHERE ADD_MONTHS (period_start_date, 1) <=
 year_end_date),
 cal_qtr (query_id,
 calendar_type,
 q_start_date,
 q_end_date,
 year_start_date,
 year_end_date,
 period_start_date,
 period_end_date,
 qtr_num,
 NO_OF_UTILIZATION_DAYS,
 NET_NUMBER_OF_DAYS)
 AS (SELECT query_id,
 calendar_type,
 q_start_date,
 q_end_date,
 period_start_date year_start_date,
 period_end_date year_end_date,
 period_start_date,
 ADD_MONTHS (period_start_date, 3) - 1
 period_end_date,
 1 qtr_num,
 NO_OF_UTILIZATION_DAYS,
 MONTHS_BETWEEN (
 LEAST (ADD_MONTHS (period_start_date, 3),
 q_end_date + 1),
 q_start_date)
 / 12
 * NO_OF_UTILIZATION_DAYS
 NET_NUMBER_OF_DAYS
 FROM cal_year cy
 UNION ALL
 SELECT query_id,
 calendar_type,
 q_start_date,
 q_end_date,
 year_start_date,
 year_end_date,
 ADD_MONTHS (period_start_date, 3)
 period_start_date,
 ADD_MONTHS (period_start_date, 6) - 1
 period_end_date,
 qtr_num + 1,
 NO_OF_UTILIZATION_DAYS,
 CASE
 WHEN q_end_date > period_end_date
 THEN
 MONTHS_BETWEEN (
 LEAST (
 ADD_MONTHS (period_start_date, 6),
 q_end_date + 1),
 ADD_MONTHS (period_start_date, 3))
 / 12
 * NO_OF_UTILIZATION_DAYS
 END
 NET_NUMBER_OF_DAYS
 FROM cal_qtr
 WHERE qtr_num < 4)
 SELECT QUERY_ID,
 period_start_date YEAR_START_DATE,
 4 PERIOD_LEVEL,
 CASE year_type
 WHEN 'CY'
 THEN
 TO_CHAR (period_end_date, '"YTD "YYYY')
 WHEN 'YE'
 THEN
 TO_CHAR (period_end_date, '"YTD "MM/YYYY')
 END
 PERIOD_NAME,
 PERIOD_START_DATE,
 PERIOD_END_DATE,
 CALENDAR_TYPE,
 NET_NUMBER_OF_DAYS
 FROM cal_year cy
 UNION ALL
 SELECT QUERY_ID,
 YEAR_START_DATE,
 1 PERIOD_LEVEL,
 TO_CHAR (period_start_date, 'MON-YYYY') PERIOD_NAME,
 PERIOD_START_DATE,
 PERIOD_END_DATE,
 CALENDAR_TYPE,
 NET_NUMBER_OF_DAYS
 FROM cal_mth
 UNION ALL
 SELECT QUERY_ID,
 YEAR_START_DATE,
 2 PERIOD_LEVEL,
 'QTD Q' || qtr_num || TO_CHAR (year_end_date, ' YYYY')
 PERIOD_NAME,
 PERIOD_START_DATE,
 PERIOD_END_DATE,
 CALENDAR_TYPE,
 NET_NUMBER_OF_DAYS
 FROM cal_qtr cq
 UNION ALL
 SELECT QUERY_ID,
 YEAR_START_DATE,
 3 PERIOD_LEVEL,
 'YTD Q' || qtr_num || TO_CHAR (year_end_date, ' YYYY')
 PERIOD_NAME,
 CASE
 WHEN q_end_date >= period_start_date
 THEN
 YEAR_START_DATE
 ELSE
 PERIOD_START_DATE
 END
 PERIOD_START_DATE,
 PERIOD_END_DATE,
 CALENDAR_TYPE,
 CASE
 WHEN q_end_date >= period_start_date
 THEN
 MONTHS_BETWEEN (
 LEAST (period_end_date, q_end_date) + 1,
 GREATEST (q_start_date, year_start_date))
 / 12
 * NO_OF_UTILIZATION_DAYS
 END
 NET_NUMBER_OF_DAYS
 FROM cal_qtr cq;

 COMMIT;

 UPDATE XXHA_ACCR_TRUEUP_PER_SUM ts
 SET (BILLING_QTY_EA, OVERRIDE_QUANTITY, net_bowls,
 BILLING_QTY_EA_nsx, OVERRIDE_QUANTITY_nsx, net_bowls_nsx) =
 (SELECT SUM (BILLING_QTY_EA) billing_qty_ea,
 SUM (OVERRIDE_QUANTITY) OVERRIDE_QUANTITY,
 SUM (total_qty) net_bowls,
 SUM (decode(NEW_SITE_EXCLUDE,'Y',0,BILLING_QTY_EA)) billing_qty_ea_nsx,
 SUM (decode(NEW_SITE_EXCLUDE,'Y',0,OVERRIDE_QUANTITY)) OVERRIDE_QUANTITY_nsx,
 SUM (decode(NEW_SITE_EXCLUDE,'Y',0,total_qty)) net_bowls_nsx
 FROM XXHA_ACCR_TRUEUP_AR_DATA ad
 WHERE ad.query_id = ts.query_id
 AND ad.trx_date BETWEEN ts.period_start_date
 AND ts.period_end_date
 AND item in ('0625B-00')) 
 WHERE ts.query_id = p_query_id;

 COMMIT;

 UPDATE XXHA_ACCR_TRUEUP_PER_SUM ts
 SET (NO_OF_DEVICES, OVERRIDE_DEVICES, AVG_DEVICES,
 NO_OF_DEVICES_nsx, OVERRIDE_DEVICES_nsx, AVG_DEVICES_nsx) =
 (SELECT SUM (NO_OF_DEVICES)
 / COUNT (DISTINCT td.period_end_date)
 NO_OF_DEVICES,
 NVL2 (SUM (OVERRIDE_DEVICES),
 SUM (total_devices),
 NULL)
 / COUNT (DISTINCT td.period_end_date)
 OVERRIDE_DEVICES,
 SUM (total_devices)
 / COUNT (DISTINCT td.period_end_date)
 avg_devices,
 SUM (greatest(NO_OF_DEVICES-decode(NEW_SITE_EXCLUDE,'Y',l_max_device_excl,0),0))
 / COUNT (DISTINCT td.period_end_date)
 NO_OF_DEVICES_nsx,
 NVL2 (SUM (greatest(OVERRIDE_DEVICES-decode(NEW_SITE_EXCLUDE,'Y',l_max_device_excl,0),0)),
 SUM (greatest(total_devices-decode(NEW_SITE_EXCLUDE,'Y',l_max_device_excl,0),0)),
 NULL)
 / COUNT (DISTINCT td.period_end_date)
 OVERRIDE_DEVICES_nsx,
 SUM (greatest(total_devices-decode(NEW_SITE_EXCLUDE,'Y',l_max_device_excl,0),0))
 / COUNT (DISTINCT td.period_end_date)
 avg_devices_nsx
 FROM XXHA_ACCR_TRUEUP_DATES TD, XXHA_ACCR_TRUEUP_PD pd
 WHERE TD.query_id = pd.query_id(+)
 AND td.period_end_date = pd.period_end_date(+)
 AND td.query_id = ts.query_id
 AND td.period_start_date BETWEEN ts.period_start_date
 AND ts.period_end_date)
 WHERE ts.query_id = p_query_id;

 COMMIT;

 UPDATE XXHA_ACCR_TRUEUP_PER_SUM ts
 SET AVG_TURN_RATE =
 ROUND (net_bowls / avg_devices / net_number_of_days, 2),
 AVG_TURN_RATE_nsx =
 ROUND (net_bowls_nsx / avg_devices_nsx / net_number_of_days, 2)
 WHERE ts.query_id = p_query_id AND NVL (avg_devices, 0) <> 0;

 COMMIT;

 INSERT INTO XXHA_ACCR_TRUEUP_SITE_SUM (QUERY_ID,
 YEAR_START_DATE,
 PERIOD_LEVEL,
 PERIOD_NAME,
 PERIOD_START_DATE,
 PERIOD_END_DATE,
 CALENDAR_TYPE,
 NET_NUMBER_OF_DAYS,
 PARTY_SITE_NUMBER,
 ADDRESS_1,
 ADDRESS_2,
 ADDRESS_3,
 ADDRESS_4,
 CITY,
 STATE,
 POSTAL_CODE,
 COUNTRY,
 SITE_LOCATION,
 NET_BOWLS,
 NET_BOWLS_NSX)
 SELECT ts.query_id,
 ts.year_start_date,
 ts.period_level,
 ts.period_name,
 ts.period_start_date,
 ts.period_end_date,
 ts.calendar_type,
 ts.net_number_of_days,
 ad.ship_to_site_number party_site_number,
 ad.ship_to_address_1 address_1,
 ad.ship_to_address_2 address_2,
 ad.ship_to_address_3 address_3,
 ad.ship_to_address_4 address_4,
 ad.ship_to_city city,
 ad.ship_to_state state,
 ad.ship_to_postal_code postal_code,
 ad.ship_to_country country,
 ad.ship_to_location site_location,
 SUM (ad.total_qty) net_bowls,
 SUM (decode(ad.NEW_SITE_EXCLUDE,'Y',0,ad.total_qty)) net_bowls_nsx
 FROM XXHA_ACCR_TRUEUP_PER_SUM ts, XXHA_ACCR_TRUEUP_AR_DATA ad
 WHERE ad.query_id = ts.query_id
 AND ad.trx_date BETWEEN ts.period_start_date
 AND ts.period_end_date
 AND ts.query_id = p_query_id
 AND ts.period_level <> 3
 AND ad.item in ('0625B-00')
 GROUP BY ts.query_id,
 ts.year_start_date,
 ts.period_level,
 ts.period_name,
 ts.period_start_date,
 ts.period_end_date,
 ts.calendar_type,
 ts.net_number_of_days,
 ad.ship_to_site_number,
 ad.ship_to_address_1,
 ad.ship_to_address_2,
 ad.ship_to_address_3,
 ad.ship_to_address_4,
 ad.ship_to_city,
 ad.ship_to_state,
 ad.ship_to_postal_code,
 ad.ship_to_country,
 ad.ship_to_location;

 COMMIT;

 MERGE INTO XXHA_ACCR_TRUEUP_SITE_SUM A
 USING ( SELECT ts.query_id,
 ts.year_start_date,
 ts.period_level,
 ts.period_name,
 ts.period_start_date,
 ts.period_end_date,
 ts.calendar_type,
 ts.net_number_of_days,
 pd.party_site_number,
 pd.address_1,
 pd.address_2,
 pd.address_3,
 pd.address_4,
 pd.city,
 pd.state,
 pd.postal_code,
 pd.country,
 pd.prod_location site_location,
 SUM (total_devices)
 / (SELECT COUNT (DISTINCT td.period_end_date)
 per_count
 FROM XXHA_ACCR_TRUEUP_DATES TD
 WHERE td.query_id = ts.query_id
 AND td.period_start_date BETWEEN ts.period_start_date
 AND ts.period_end_date)
 avg_devices,
 SUM (greatest(total_devices - decode(NEW_SITE_EXCLUDE,'Y',l_max_device_excl,0),0))
 / (SELECT COUNT (DISTINCT td.period_end_date)
 per_count
 FROM XXHA_ACCR_TRUEUP_DATES TD
 WHERE td.query_id = ts.query_id
 AND td.period_start_date BETWEEN ts.period_start_date
 AND ts.period_end_date)
 avg_devices_nsx
 FROM XXHA_ACCR_TRUEUP_PER_SUM ts,
 XXHA_ACCR_TRUEUP_PD pd
 WHERE pd.query_id = ts.query_id
 AND pd.period_end_date BETWEEN ts.period_start_date
 AND ts.period_end_date
 AND ts.query_id = p_query_id
 AND ts.period_level <> 3
 GROUP BY ts.query_id,
 ts.year_start_date,
 ts.period_level,
 ts.period_name,
 ts.period_start_date,
 ts.period_end_date,
 ts.calendar_type,
 ts.net_number_of_days,
 pd.party_site_number,
 pd.address_1,
 pd.address_2,
 pd.address_3,
 pd.address_4,
 pd.city,
 pd.state,
 pd.postal_code,
 pd.country,
 pd.prod_location) B
 ON ( A.query_id = B.query_id
 AND A.PERIOD_LEVEL = B.PERIOD_LEVEL
 AND A.PERIOD_START_DATE = B.PERIOD_START_DATE
 AND A.party_site_number = B.party_site_number)
 WHEN NOT MATCHED
 THEN
 INSERT (QUERY_ID,
 YEAR_START_DATE,
 PERIOD_LEVEL,
 PERIOD_NAME,
 PERIOD_START_DATE,
 PERIOD_END_DATE,
 CALENDAR_TYPE,
 NET_NUMBER_OF_DAYS,
 PARTY_SITE_NUMBER,
 ADDRESS_1,
 ADDRESS_2,
 ADDRESS_3,
 ADDRESS_4,
 CITY,
 STATE,
 POSTAL_CODE,
 COUNTRY,
 SITE_LOCATION,
 AVG_DEVICES,
 AVG_DEVICES_NSX)
 VALUES (B.QUERY_ID,
 B.YEAR_START_DATE,
 B.PERIOD_LEVEL,
 B.PERIOD_NAME,
 B.PERIOD_START_DATE,
 B.PERIOD_END_DATE,
 B.CALENDAR_TYPE,
 B.NET_NUMBER_OF_DAYS,
 B.PARTY_SITE_NUMBER,
 B.ADDRESS_1,
 B.ADDRESS_2,
 B.ADDRESS_3,
 B.ADDRESS_4,
 B.CITY,
 B.STATE,
 B.POSTAL_CODE,
 B.COUNTRY,
 B.SITE_LOCATION,
 NULLIF (B.AVG_DEVICES, 0),
 NULLIF (B.AVG_DEVICES_NSX, 0))
 WHEN MATCHED
 THEN
 UPDATE SET
 A.AVG_DEVICES = B.AVG_DEVICES,
 A.avg_turn_rate =
 ROUND (A.net_bowls / B.avg_devices / A.net_number_of_days,
 2),
 A.AVG_DEVICES_nsx = B.AVG_DEVICES_nsx,
 A.avg_turn_rate_nsx = case when NVL (B.avg_devices_nsx, 0) <> 0 then
 ROUND (A.net_bowls_nsx / case when NVL (B.avg_devices_nsx, 0) = 0 then 1 else B.avg_devices_nsx end / A.net_number_of_days,
 2) end
 WHERE NVL (B.avg_devices, 0) <> 0;

 COMMIT;

 UPDATE XXHA_ACCR_TRUEUP_CTRL
 SET HAS_DATA = 'Y'
 WHERE query_id = p_query_id;

 COMMIT;

 RUN_REPORT (l_query_id_c);
 END IF;
 END GET_DATA;

 --Function to detect if data has already been generated for query_id
 FUNCTION HAS_DATA (p_query_id IN NUMBER)
 RETURN VARCHAR2
 IS
 l_has_data VARCHAR2 (1);
 BEGIN
 SELECT NVL (MAX (has_data), 'N') has_data
 INTO l_has_data
 FROM xxha_accr_trueup_ctrl
 WHERE query_id = p_query_id;

 RETURN l_has_data;
 END HAS_DATA;
END XXHA_ACCRUAL_TRUEUP;
/

