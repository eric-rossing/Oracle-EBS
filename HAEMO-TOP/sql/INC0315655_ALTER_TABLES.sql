alter table haemo.XXHA_ACCR_TRUEUP_AR_DATA
add (NEW_SITE_EXCLUDE CHAR(1));

alter table haemo.XXHA_ACCR_TRUEUP_IB_DATA
add (NEW_SITE_EXCLUDE CHAR(1));

alter table haemo.XXHA_ACCR_TRUEUP_PD
add (NEW_SITE_EXCLUDE CHAR(1));

alter table haemo.XXHA_ACCR_TRUEUP_PRICE
add (BOWL_PRICE NUMBER);

alter table haemo.XXHA_ACCR_TRUEUP_SUM
add (ACTUAL_UTIL_CHARGE NUMBER,
     TARGET_UTIL_CHARGE NUMBER,
     PRICE_AT_TARGET_UTIL NUMBER,
     NET_BOWLS_NSX NUMBER,
     ACTUAL_INVOICED_NSX NUMBER,
     AVG_DEVICES_nsx NUMBER,
     actual_utilization_nsx number,
     ACTUAL_UTIL_CHARGE_NSX NUMBER,
     PRICE_AT_TARGET_UTIL_NSX NUMBER,
     PRICE_AT_ACTUAL_UTIL_NSX NUMBER,
     TRUE_UP_AMT_NSX NUMBER);

alter table haemo.XXHA_ACCR_TRUEUP_SITE_SUM
add (net_bowls_NSX NUMBER,
     ACTUAL_INVOICED_NSX NUMBER,
     AVG_DEVICES_nsx NUMBER,
     avg_turn_rate_nsx NUMBER);
     
alter table haemo.XXHA_ACCR_TRUEUP_PER_SUM
add (BILLING_QTY_EA_NSX NUMBER,    
     OVERRIDE_QUANTITY_NSX NUMBER,
     NET_BOWLS_NSX NUMBER,
     NO_OF_DEVICES_NSX NUMBER,
     OVERRIDE_DEVICES_NSX NUMBER,
     AVG_DEVICES_NSX NUMBER,
     AVG_TURN_RATE_NSX NUMBER);


--Tables for form

ALTER TABLE haemo.xxha_accr_trueup_query_hdr ADD No_of_devices NUMBER;

ALTER TABLE haemo.xxha_accr_trueup_query_site ADD START_DATE DATE;

ALTER TABLE haemo.xxha_accr_trueup_query_site ADD END_DATE  DATE;

CREATE OR REPLACE FORCE VIEW APPS.XXHA_ACCR_CUST_SITE_V
(
   PARTY_NAME,
   CUSTOMER_NAME,
   PARTY_SITE_NUMBER,
   PARTY_ID,
   PARTY_SITE_ID,
   ACTIVE_FLAG,
   QUERY_ID,
   SESSION_ID,
   START_DATE,
   END_DATE
)
AS
   SELECT    hps.party_site_number
          || '-'
          || hp.party_name
          || '-'
          || hl.city
          || '-'
          || hl.state
          || '-'
          || hl.postal_code
          || '-'
          || hl.country
             party_name,
          hp.party_name customer_name,
          hps.party_site_number,
          hp.party_id,
          hps.party_site_id,
          xats.active_flag,
          xats.query_id,
          xats.session_id,
          xats.start_date,
          xats.end_Date
     FROM hz_parties hp,
          hz_party_sites hps,
          hz_locations hl,
          xxha_accr_trueup_query_site xats
    WHERE     hp.party_id = hps.party_id
          AND hps.location_id = hl.location_id
          AND hp.category_code = 'PLASMA'
          AND xats.party_site_id = hps.party_site_id
          AND hp.status = 'A'
          AND hps.status = 'A'
          AND EXISTS
                 (SELECT 1
                    FROM hz_cust_acct_sites_all hcas,
                         hz_cust_site_uses_all hcsu
                   WHERE     hcas.party_site_id = hps.party_site_id
                         AND hcas.cust_acct_site_id = hcsu.cust_acct_site_id
                         AND hcsu.site_use_code IN ('SHIP_TO', 'INSTALL-AT')
                         AND hcas.org_id = FND_PROFILE.VALUE ('ORG_ID'));