create or replace PACKAGE XXHA_REG_WEBADI_DATA_INTERFACE
AS
    PROCEDURE LOAD_REG_HEADER_DATA (
                    P_COUNTRY_CODE                  VARCHAR2,
                    P_COUNTRY                       VARCHAR2,
                    P_STATE                         VARCHAR2, 
                    P_PROVINCE                      VARCHAR2,
                    P_SITE_CONTROL_TYPE             VARCHAR2,  
                    P_ITEM_CONTROL_TYPE             VARCHAR2,
                    P_BUSINESS_LICENSE_REQUIRED     VARCHAR2,
                    P_REGULATORY_LICENSE_REQUIRED   VARCHAR2,
                    P_APPROVED_PRODUCT_LIST         VARCHAR2,  
                    P_REGULATORY_NOTIFICATION       VARCHAR2, 
                    P_CUST_SERVICE_NOTIFICATION     VARCHAR2, 
                    P_REGULATORY_REGISTRATION_REQ   VARCHAR2,
                    P_EXPIRING_NOTIFICATION_DATE    VARCHAR2
                    );
   PROCEDURE UPDATE_HEADER_DATA (
                    COUNTRY_CODE VARCHAR2,
                    COUNTRY      VARCHAR2,
                    STATE        VARCHAR2, 
                    PROVINCE     VARCHAR2,
                    SITE_CONTROL_TYPE   VARCHAR2,  
                    ITEM_CONTROL_TYPE   VARCHAR2,
                    BUSINESS_LICENSE_REQUIRED  VARCHAR2,
                    REGULATORY_LICENSE_REQUIRED  VARCHAR2,
                    APPROVED_PRODUCT_LIST        VARCHAR2,  
                    REGULATORY_NOTIFICATION      VARCHAR2, 
                    CUSTOMER_SERVICE_NOTIFICATION VARCHAR2, 
                    REGULATORY_REGISTRATION_REQ   VARCHAR2,
                    P_CHANGE_TYPE   VARCHAR2,
                    P_EXPIRING_NOTIFICATION_DATE    VARCHAR2
                    );
   PROCEDURE LOAD_ITEM_INCLUSION (
                    P_ITEM_NUMBER       VARCHAR2,
                    P_ITEM_DESCRIPTION  VARCHAR2,
                    P_REGULATORY_AGENCY        VARCHAR2, 
                    P_REGISTRATION_NUM          VARCHAR2,
                    P_REG_START_DATE          DATE,
                    P_REG_END_DATE            DATE,
                    P_COUNTRY_CODE          VARCHAR2,
                    P_REGISTERED_LEGAL_ENTITY          VARCHAR2,
                    P_MANUFACTURING_SITE    VARCHAR2,
                    P_ITEM_NAME_LOCAL_LANGUAGE    VARCHAR2,
                    P_PACKING_STD_EQUIP_MODEL    VARCHAR2,
                    P_CATEGORY_CODE    VARCHAR2
                    );
   PROCEDURE LOAD_ITEM_EXCLUSION (
                    P_ITEM_NUMBER           VARCHAR2,
                    P_ITEM_DESCRIPTION      VARCHAR2,
                    P_REG_START_DATE        DATE,
                    P_REG_END_DATE          DATE,
                    P_COUNTRY_CODE          VARCHAR2);
       PROCEDURE LOAD_REGULATORY_CUSTOMER (
                    P_ACCOUNT_NUMBER        NUMBER,
                    P_ACCOUNT_NAME          VARCHAR2,
                    P_CONTROL_TYPE          VARCHAR2,
                    P_REGULATORY_AGENCY     VARCHAR2,
                    P_LICENSE_NO            VARCHAR2,
                    P_CUST_REG_START_DATE        DATE,
                    P_CUST_REG_END_DATE          DATE,
                    P_APL                   VARCHAR2,
                    P_CUSTOMER_TYPE                       VARCHAR2,
                    P_SCOPE_OF_MEDICAL_DEVICE_LIC                   VARCHAR2,
                    P_COUNTRY_CODE          VARCHAR2);
          PROCEDURE LOAD_REG_CUSTOMER_APPRV_LIST (
                    P_ITEM_NUMBER        VARCHAR2,
                    P_ITEM_DESCRIPTION          VARCHAR2,
                    P_MEDICAL_DEVICE_CATEGORY          VARCHAR2,
                    P_APL_START_DATE        DATE,
                    P_APL_END_DATE          DATE,
                    P_CUSTOMER_NAME          VARCHAR2,
                    P_COUNTRY_CODE          VARCHAR2);
  PROCEDURE UPDATE_ITEM_INCLUSION
    (
      P_ITEM_NUMBER              VARCHAR2,
      P_ITEM_DESCRIPTION         VARCHAR2,
      P_REGULATORY_AGENCY        VARCHAR2,
      P_REGISTRATION_NUM         VARCHAR2,
      P_REG_START_DATE           DATE,
      P_REG_END_DATE             DATE,
      P_COUNTRY_CODE             VARCHAR2,
      P_REGISTERED_LEGAL_ENTITY  VARCHAR2,
      P_MANUFACTURING_SITE       VARCHAR2,
      P_ITEM_NAME_LOCAL_LANGUAGE VARCHAR2,
      P_PACKING_STD_EQUIP_MODEL  VARCHAR2,
      P_CATEGORY_CODE            VARCHAR2,
      P_NEW_REGISTRATION_NUM     VARCHAR2    --Added by  praduman  on  14-Jul-2020 to  Update  Registration  Number
    );
    PROCEDURE UPDATE_ITEM_EXCLUSION
     (
      P_ITEM_NUMBER              VARCHAR2,
      P_ITEM_DESCRIPTION         VARCHAR2,
      P_REG_START_DATE           DATE,
      P_REG_END_DATE             DATE,
      P_COUNTRY_CODE             VARCHAR2
    );
     PROCEDURE UPDATE_REGULATORY_CUSTOMER
      (
      P_ACCOUNT_NUMBER              NUMBER,
      P_ACCOUNT_NAME                VARCHAR2,
      P_CONTROL_TYPE                VARCHAR2,
      P_REGULATORY_AGENCY           VARCHAR2,
      P_LICENSE_NO                  VARCHAR2,
      P_CUST_REG_START_DATE         DATE,
      P_CUST_REG_END_DATE           DATE,
      P_APL                         VARCHAR2,
      P_CUSTOMER_TYPE               VARCHAR2,
      P_SCOPE_OF_MEDICAL_DEVICE_LIC VARCHAR2,
      P_COUNTRY_CODE                VARCHAR2
    );
    PROCEDURE UPDATE_REG_CUSTOMER_APPRV_LIST
    (
      P_ITEM_NUMBER             VARCHAR2,
      P_ITEM_DESCRIPTION        VARCHAR2,
      P_MEDICAL_DEVICE_CATEGORY VARCHAR2,
      P_APL_START_DATE          DATE,
      P_APL_END_DATE            DATE,
      P_CUSTOMER_NAME           VARCHAR2,
      P_COUNTRY_CODE            VARCHAR2
    );
  END;