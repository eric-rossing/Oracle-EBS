create or replace PACKAGE body XXHA_REG_WEBADI_DATA_INTERFACE
AS
/*==========================================================================|
|			 		     												                                      |
|  * Developer     : Praduman Singh                                         |
|  * Client/Project : HEMONETICS                                            |
|  * Date           : 27-Jan-2020                                           |
|  * Description    : This package contains the logic for Web ADI upload for| 
|                     Regulatory Header And Lines custom tables             |
|  * Issue          :                                                       |
|  * Version Control:                                                       |
|  * Author        Version             Date               Change            |
|   * -------       -------            --------          -------            |
|   * Praduman        0.0              27-Jan-2020         Initail Veriosn  |
|==========================================================================|*/
  PROCEDURE LOAD_REG_HEADER_DATA(
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
                    P_EXPIRING_NOTIFICATION_DATE    VARCHAR2)
  AS
    l_Country_Control_Id  NUMBER;
    l_country_active_flag NUMBER;
    l_country_code        VARCHAR2 (15);
    l_country             VARCHAR2 (100);
    l_state               VARCHAR2 (150);
    l_province            VARCHAR2 (150);
    l_error_msg           NUMBER DEFAULT NULL;
    l_status              VARCHAR2 (10);
    l_error_flag          VARCHAR2 (10);
   -- p_country             VARCHAR2 (15);
    l_change_type         VARCHAR2 (15);
  BEGIN
    l_status := 'N';
    BEGIN
      SELECT MAX(country_control_id)+1
      INTO L_Country_Control_Id
      FROM xxha_reg_country_control;
    END;
    BEGIN
      SELECT DISTINCT territory_code code
      INTO l_country_code
      FROM fnd_territories_tl
      WHERE language                   = 'US'
      AND UPPER( territory_short_name) =UPPER(p_country);
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
      raise_application_error (-20001, ' No Data Found For Country Code'||p_country);
      l_status    := 'E';
      l_error_msg := SQLERRM;
    WHEN OTHERS THEN
      raise_application_error (-20001, SQLERRM);
      l_status    := 'E';
      l_error_msg := SQLERRM;
    END;
    BEGIN
      SELECT DISTINCT territory_short_name
      INTO l_country
      FROM fnd_territories_tl
      WHERE language                   = 'US'
      AND UPPER( territory_code)       =upper(l_country_code)
      AND UPPER( territory_short_name) =upper(p_country);
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
      raise_application_error (-20001, ' No Data Found For Country');
      l_status    := 'E';
      l_error_msg := SQLERRM;
    WHEN OTHERS THEN
      raise_application_error (-20001, SQLERRM);
      l_status    := 'E';
      l_error_msg := SQLERRM;
    END;
    IF P_STATE IS NOT NULL THEN
      BEGIN
        SELECT DISTINCT STATE
        INTO l_state
        FROM hz_locations
        WHERE UPPER(country) = p_country
        AND UPPER(state)     = p_state;
      EXCEPTION
      WHEN NO_DATA_FOUND THEN
        raise_application_error (-20001, ' No Data Found For State');
        l_status    := 'E';
        l_error_msg := SQLERRM;
      WHEN OTHERS THEN
        raise_application_error (-20001, SQLERRM);
        l_status    := 'E';
        l_error_msg := SQLERRM;
      END;
    END IF;
    IF P_PROVINCE IS NOT NULL THEN
      BEGIN
        SELECT DISTINCT PROVINCE
        INTO l_province
        FROM hz_locations
        WHERE UPPER(country) = p_country
        AND UPPER(province)  = p_province;
      EXCEPTION
      WHEN NO_DATA_FOUND THEN
        raise_application_error (-20001, ' No Data Found For Province');
        l_status    := 'E';
        l_error_msg := SQLERRM;
      WHEN OTHERS THEN
        raise_application_error (-20001, SQLERRM);
        l_status    := 'E';
        l_error_msg := SQLERRM;
      END;
    END IF;
    BEGIN
      SELECT COUNT(1)
      INTO l_country_active_flag
      FROM xxha_reg_country_control t1
      WHERE 1                   =1
      AND t1.country            = l_country
      AND NVL(t1.state,'XX')    = NVL(p_state, NVL(t1.state,'XX'))
      AND NVL(t1.province,'XX') = NVL(p_province, NVL(t1.province,'XX'));
      IF l_country_active_flag  > 0 THEN
        raise_application_error ( -20001,' Record for entered Country already exists.'||l_country_active_flag||P_COUNTRY);
        l_status    := 'E';
        l_error_msg := SQLERRM;
      END IF;
    END;
    -- L_COUNTRY_CONTROL_ID := (SELECT MAX(COUNTRY_CONTROL_ID)+1 FROM XXHA_REG_COUNTRY_CONTROL);
    -- l_status := 'N';
    BEGIN
      INSERT
      INTO xxha_reg_country_control
        (
          COUNTRY_CONTROL_ID,
          COUNTRY_CODE ,
          COUNTRY ,
          STATE,
          PROVINCE,
          SITE_CONTROL_TYPE,
          ITEM_CONTROL_TYPE ,
          BUSINESS_LICENSE_REQUIRED ,
          REGULATORY_LICENSE_REQUIRED,
          APPROVED_PRODUCT_LIST,
          REGULATORY_NOTIFICATION,
          CUSTOMER_SERVICE_NOTIFICATION,
          REGULATORY_REGISTRATION_REQ,
          EXPIRING_NOTIFICATION_DATE,
          ENABLED_FLAG ,
          CREATION_DATE ,
          CREATED_BY ,
          LAST_UPDATE_DATE,
          LAST_UPDATED_BY
        )
        VALUES
        (
          l_COUNTRY_CONTROL_ID,
          l_COUNTRY_CODE ,
          INITCAP(l_COUNTRY) ,
          INITCAP(l_STATE),
          INITCAP(l_PROVINCE),
          INITCAP(P_SITE_CONTROL_TYPE),
          INITCAP(P_ITEM_CONTROL_TYPE) ,
          INITCAP(P_BUSINESS_LICENSE_REQUIRED) ,
          INITCAP(P_REGULATORY_LICENSE_REQUIRED),
          INITCAP(P_APPROVED_PRODUCT_LIST),
          P_REGULATORY_NOTIFICATION,
          P_CUST_SERVICE_NOTIFICATION,
          INITCAP(P_REGULATORY_REGISTRATION_REQ),
          P_EXPIRING_NOTIFICATION_DATE,
          'No',
          SYSDATE ,
          NVL(fnd_profile.VALUE ('USER_ID'),'-1') ,
          SYSDATE,
          fnd_profile.VALUE ('USER_ID')
        );
    END;
  END;
  PROCEDURE UPDATE_HEADER_DATA
    (
      COUNTRY_CODE                  VARCHAR2,
      COUNTRY                       VARCHAR2,
      STATE                         VARCHAR2,
      PROVINCE                      VARCHAR2,
      SITE_CONTROL_TYPE             VARCHAR2,
      ITEM_CONTROL_TYPE             VARCHAR2,
      BUSINESS_LICENSE_REQUIRED     VARCHAR2,
      REGULATORY_LICENSE_REQUIRED   VARCHAR2,
      APPROVED_PRODUCT_LIST         VARCHAR2,
      REGULATORY_NOTIFICATION       VARCHAR2,
      CUSTOMER_SERVICE_NOTIFICATION VARCHAR2,
      REGULATORY_REGISTRATION_REQ   VARCHAR2,
      P_CHANGE_TYPE                 VARCHAR2,
      P_EXPIRING_NOTIFICATION_DATE  VARCHAR2
    )
  AS
    L_Country_Control_Id          NUMBER;
    l_country_active_flag         NUMBER;
    l_country_code                VARCHAR2 (15);
    l_country                     VARCHAR2 (100);
    l_state                       VARCHAR2 (150);
    l_province                    VARCHAR2 (150);
    l_error_msg                   NUMBER DEFAULT NULL;
    l_status                      VARCHAR2 (10);
    l_error_flag                  VARCHAR2 (10);
    p_country                     VARCHAR2 (100);
    l_change_type                 VARCHAR2 (15);
    L_SITE_CONTROL_TYPE           VARCHAR2 (50);
    L_ITEM_CONTROL_TYPE           VARCHAR2 (50);
    L_BUSINESS_LICENSE_REQUIRED   VARCHAR2 (50);
    L_REGULATORY_LICENSE_REQUIRED VARCHAR2 (50);
    L_APPROVED_PRODUCT_LIST       VARCHAR2 (50);
    L_REGULATORY_NOTIFICATION     VARCHAR2 (50);
    L_CUSTOMER_SERVICE_NOTI       VARCHAR2 (50);
    L_REGULATORY_REGISTRATION_REQ VARCHAR2 (50);
  BEGIN
    l_status                      := 'N';
    l_change_type                 := 'UPDATE';--P_CHANGE_TYPE;
    p_country                     := country;
    l_country_code                := country_code;
    L_SITE_CONTROL_TYPE           := SITE_CONTROL_TYPE;
    L_ITEM_CONTROL_TYPE           := ITEM_CONTROL_TYPE;
    L_BUSINESS_LICENSE_REQUIRED   := BUSINESS_LICENSE_REQUIRED;
    L_REGULATORY_LICENSE_REQUIRED := REGULATORY_LICENSE_REQUIRED;
    L_APPROVED_PRODUCT_LIST       := APPROVED_PRODUCT_LIST;
    L_REGULATORY_NOTIFICATION     := REGULATORY_NOTIFICATION;
    L_CUSTOMER_SERVICE_NOTI       := CUSTOMER_SERVICE_NOTIFICATION;
    L_REGULATORY_REGISTRATION_REQ := REGULATORY_REGISTRATION_REQ;
    
    BEGIN
      SELECT DISTINCT territory_code code
      INTO l_country_code
      FROM fnd_territories_tl
      WHERE language                   = 'US'
      AND UPPER( territory_short_name) =upper(p_country);
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
      raise_application_error (-20001, ' No Data Found For Country Code'||P_CHANGE_TYPE);
      l_status    := 'E';
      l_error_msg := SQLERRM;
    WHEN OTHERS THEN
      raise_application_error (-20001, SQLERRM);
      l_status    := 'E';
      l_error_msg := SQLERRM;
    END;
    
    BEGIN
      SELECT DISTINCT territory_short_name
      INTO l_country
      FROM fnd_territories_tl
      WHERE language                   = 'US'
      AND UPPER( territory_code)       =upper(l_country_code)
      AND UPPER( territory_short_name) =upper(p_COUNTRY);
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
      raise_application_error (-20001, ' No Data Found For Country');
      l_status    := 'E';
      l_error_msg := SQLERRM;
    WHEN OTHERS THEN
      raise_application_error (-20001, SQLERRM);
      l_status    := 'E';
      l_error_msg := SQLERRM;
    END;
   
    BEGIN
      IF STATE IS NOT NULL THEN
        BEGIN
          SELECT DISTINCT STATE
          INTO l_state
          FROM HZ_LOCATIONS
          WHERE UPPER(country) = COUNTRY
          AND UPPER(STATE)     = STATE;
        EXCEPTION
        WHEN NO_DATA_FOUND THEN
          raise_application_error (-20001, ' No Data Found For State');
          l_status    := 'E';
          l_error_msg := SQLERRM;
        WHEN OTHERS THEN
          raise_application_error (-20001, SQLERRM);
          l_status    := 'E';
          l_error_msg := SQLERRM;
        END;
      END IF;
    END;
    IF PROVINCE IS NOT NULL THEN
      BEGIN
        SELECT DISTINCT Province
        INTO l_province
        FROM hz_locations
        WHERE UPPER(country) = country
        AND UPPER(province)  = province;
      EXCEPTION
      WHEN NO_DATA_FOUND THEN
        raise_application_error (-20001, ' No Data Found For Province');
        l_status    := 'E';
        l_error_msg := SQLERRM;
      WHEN OTHERS THEN
        raise_application_error (-20001, SQLERRM);
        l_status    := 'E';
        l_error_msg := SQLERRM;
      END;
    END IF;
    BEGIN
      SELECT COUNT(1)
      INTO l_country_active_flag
      FROM xxha_reg_country_control t1
      WHERE 1                   =1
      AND t1.country            = l_country
      AND NVL(t1.state,'XX')    = NVL(state, NVL(t1.state,'XX'))
      AND NVL(t1.province,'XX') = NVL(Province, NVL(t1.province,'XX'));
      IF l_country_active_flag  > 0 THEN-- AND --l_change_type = 'UPDATE' THEN
        UPDATE XXHA_REG_COUNTRY_CONTROL T1
        SET t1.site_control_type           = NVL(l_site_control_type,t1.site_control_type),
            t1.item_control_type             = NVL(l_item_control_type,t1.item_control_type),
            t1.business_license_required     = NVL(INITCAP(l_business_license_required),t1.business_license_required),
            t1.regulatory_license_required   = NVL(INITCAP(l_regulatory_license_required),t1.regulatory_license_required),
            t1.approved_product_list         = NVL(INITCAP(l_approved_product_list),t1.approved_product_list),
            t1.regulatory_notification       = NVL(l_regulatory_notification,t1.regulatory_notification),
            t1.customer_service_notification = NVL(l_customer_service_noti,t1.customer_service_notification),
            t1.regulatory_registration_req   = NVL(INITCAP(l_regulatory_registration_req),t1.regulatory_registration_req),
            t1.expiring_notification_date  =   NVL(p_expiring_notification_date,t1.expiring_notification_date),
            t1.last_update_date              = SYSDATE,
            t1.last_updated_by               = fnd_profile.VALUE ('USER_ID')
        WHERE t1.country                     = l_country
        AND   t1.country_code                = l_country_code
          -- AND   T1.COUNTRY_CONTROL_ID  =
        AND NVL(t1.state,'XX')    = NVL(state, NVL(t1.state,'XX'))
        AND NVL(t1.province,'XX') = NVL(Province, NVL(t1.province,'XX'));
      ELSE
        raise_application_error ( -20001,' Record does not exists for update Please Insert the record'||P_COUNTRY);
        l_status    := 'E';
        l_error_msg := SQLERRM;
        --   END IF;
      END IF;
    END;
  END;
  PROCEDURE LOAD_ITEM_INCLUSION(
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
      P_CATEGORY_CODE            VARCHAR2
      --  P_CHANGE_TYPE   VARCHAR2
    )
  IS
    l_Country_Control_Id   NUMBER;
    l_Item_Registration_Id NUMBER;
    l_item_active_flag     NUMBER;
    l_country_code         VARCHAR2 (15);
    l_Item_Number          VARCHAR2 (100);
    l_description          VARCHAR2 (150);
    l_province             VARCHAR2 (150);
    l_error_msg            NUMBER DEFAULT NULL;
    l_status               VARCHAR2 (10);
    l_ERROR_flag           VARCHAR2 (10);
    l_active_flag          VARCHAR2 (5);
  BEGIN
    /*BEGIN
      SELECT NVL(MAX(item_registration_id),1000)+1
      INTO l_Item_Registration_Id
      FROM xxha_item_registration;
    END;*/
    BEGIN
      SELECT Country_Control_Id
      INTO l_Country_Control_Id
      FROM xxha_reg_country_control
      WHERE UPPER(country_code) = UPPER(p_country_code);
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
      raise_application_error (-20001, ' No Data Found For Country Code');
      l_status    := 'E';
      l_error_msg := SQLERRM;
    WHEN OTHERS THEN
      raise_application_error (-20001, SQLERRM);
      l_status    := 'E';
      l_error_msg := SQLERRM;
    END;
    BEGIN
         SELECT DISTINCT 
               msib.segment1,
               msib.description
          INTO l_Item_Number,
               l_description
          FROM mtl_system_items_b msib
          WHERE organization_id = 103
          AND msib.segment1     = P_ITEM_NUMBER;
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
      raise_application_error (-20001, ' No Data Found For Item Number');
      l_status    := 'E';
      l_error_msg := SQLERRM;
    WHEN OTHERS THEN
      raise_application_error (-20001, SQLERRM);
      l_status    := 'E';
      l_error_msg := SQLERRM;
    END;
    BEGIN
      IF P_REG_END_DATE     IS NOT NULL THEN
        IF P_REG_START_DATE >= P_REG_END_DATE THEN
          raise_application_error (-20001, ' Effective Start Date entered should be less than Effective End Date.');
          l_status    := 'E';
          l_error_msg := SQLERRM;
        END IF;
      END IF;
    END;
    BEGIN
      IF NVL(P_REG_END_DATE,sysdate) >= sysdate THEN
        l_active_flag := 'Y';
      ELSE
        l_active_flag := 'N';
      END IF;
    END;
    BEGIN
      IF p_country_code IN ('CN','CA') THEN
        SELECT COUNT(1)
        INTO l_item_active_flag
        FROM xxha_reg_country_control T1,
             xxha_item_registration T2
        WHERE t1.country_control_id              = t2.country_control_id
          -- AND T1.COUNTRY_CONTROL_ID   = l_COUNTRY_CONTROL_ID
        AND   t1.country_code                    = p_country_code
        AND   t2.item_number                     = p_item_number
        AND   NVL(p_reg_end_date,'01-JAN-4977') >= NVL(t2.item_reg_start_date, '01-JAN-4977')
        AND   p_reg_start_date                  <= NVL(t2.item_reg_end_date, '01-JAN-4977');
        -- AND T2.ITEM_REGISTRATION_ID            <> NVL(l_Item_Registration_Id , 0000);
      ELSE
        SELECT COUNT(1)
        INTO l_item_active_flag
        FROM xxha_reg_country_control t1,
             xxha_item_registration t2
        WHERE t1.country_control_id              = t2.country_control_id
        AND   t1.country_control_id              = l_country_control_id
        AND   t1.country_code                    = p_country_code
        AND   t2.item_number                     = p_item_number
        AND   NVL(t2.Registration_Num,'XX')      = NVL(p_registration_num, NVL(t2.registration_num,'XX'))
        AND   NVL(p_reg_end_date,'01-JAN-4977') >= NVL(t2.item_reg_start_date, '01-JAN-4977')
        AND   p_reg_start_date                  <= NVL(t2.item_reg_end_date, '01-JAN-4977')
        AND   t2.item_registration_id           <> NVL(l_item_registration_id, 0000000000000000001);
      END IF;
      BEGIN
        IF l_item_active_flag <> 0 THEN
            raise_application_error (-20001,'Effective Start Date entered overlaps with existing registration. Please enter different Date');
            l_status    := 'E';
            l_error_msg := SQLERRM;
        END IF;
      END;
    EXCEPTION
   /* WHEN NO_DATA_FOUND THEN
      NULL;
       raise_application_error (-20001,
      ' No Data Found For Item Number');
      l_status := 'E';
      l_error_msg := SQLERRM;*/
      WHEN OTHERS
      THEN
      raise_application_error (-20001, SQLERRM);
      l_status := 'E';
      l_error_msg := SQLERRM;
    END;
    BEGIN
      IF p_reg_end_date < p_reg_start_date THEN
        raise_application_error (-20001, ' Effective End Date entered is less than Effective start date.');
        l_status    := 'E';
        l_error_msg := SQLERRM;
      END IF;
    END;
     BEGIN
      IF P_Country_Code IN ('CN','CA') THEN
        SELECT COUNT(1)
        INTO l_item_active_flag
        FROM xxha_reg_country_control t1,
             xxha_item_registration t2
        WHERE t1.country_control_id            = t2.country_control_id
        AND t1.country_control_id              = l_country_control_id
        AND t1.country_code                    = p_country_code
        AND t2.item_number                     = p_item_number
        AND NVL(p_reg_end_date,'01-JAN-4977') >= NVL(t2.item_reg_start_date, '01-JAN-4977')
        AND p_reg_start_date                  <= NVL(t2.item_reg_end_date, '01-JAN-4977')
        AND t2.item_registration_id           <> NVL(l_item_registration_id, 0000000000000000001);
     ELSE
        SELECT COUNT(1)
        INTO l_item_active_flag
        FROM xxha_reg_country_control t1,
             xxha_item_registration t2
        WHERE t1.country_control_id              = t2.country_control_id
        AND   t1.country_control_id              = l_country_control_id
        AND   t1.country_code                    = p_country_code
        AND   t2.item_number                     = p_item_number
        AND   NVL(p_reg_end_date,'01-JAN-4977') >= NVL(T2.item_reg_start_date, '01-JAN-4977')
        AND   p_reg_start_date                  <= NVL(t2.item_reg_end_date, '01-JAN-4977')
        AND   NVL(t2.registration_num,'XX')      = NVL(p_registration_num, NVL(t2.registration_num,'XX'))
        AND   t2.item_registration_id           <> NVL(l_item_registration_id, 0000000000000000001);
    END IF;   
    IF l_item_active_flag <> 0 THEN
        raise_application_error (-20001,'Effective End Date entered overlaps with existing registration. Please enter different Date');
        l_status    := 'E';
        l_error_msg := SQLERRM;
    END IF;
    /* raise_application_error (-20001,
    ' No Data Found For Item Number');
    l_status := 'E';
    l_error_msg := SQLERRM;*/
    EXCEPTION
    WHEN OTHERS
    THEN
      raise_application_error (-20001, SQLERRM);
      l_status := 'E';
      l_error_msg := SQLERRM;
    END;
    INSERT
    INTO xxha_item_registration
      (
        item_registration_id,
        item_number,
        item_description ,
        regulatory_agency ,
        registration_num ,
        item_reg_start_date ,
        item_reg_end_date ,
        country_control_id,
        registered_legal_entity ,
        manufacturing_site ,
        item_name_local_language ,
        packing_std_equip_model ,
        category_code ,
        active_flag,
        creation_date ,
        created_by ,
        last_update_date ,
        last_updated_by
      )
      VALUES
      (
        XXHA_REG_COUNTRY_ITEM_ID_S.NEXTVAL,--l_item_registration_id,
        l_item_number,
        l_description,
        p_regulatory_agency ,
        p_registration_num ,
        p_reg_start_date ,
        p_reg_end_date ,
        l_country_control_id ,
        p_registered_legal_entity ,
        p_manufacturing_site ,
        p_item_name_local_language ,
        p_packing_std_equip_model,
        p_category_code ,
        l_active_flag,
        SYSDATE,
        fnd_profile.VALUE ('USER_ID'),
        SYSDATE,
        fnd_profile.VALUE ('USER_ID')
      );
  END;
  PROCEDURE LOAD_ITEM_EXCLUSION
    (
      P_ITEM_NUMBER      VARCHAR2,
      P_ITEM_DESCRIPTION VARCHAR2,
      P_REG_START_DATE   DATE,
      P_REG_END_DATE     DATE,
      P_COUNTRY_CODE     VARCHAR2
    )
  IS
    l_country_control_id  NUMBER;
    l_item_exclusion_id   NUMBER;
    l_item_active_flag    NUMBER;
    l_item_exist_flag     NUMBER;
    l_country_code        VARCHAR2 (15);
    l_Item_Number         VARCHAR2 (100);
    l_description         VARCHAR2 (150);
    l_error_msg           NUMBER DEFAULT NULL;
    l_status              VARCHAR2 (10);
    l_error_flag          VARCHAR2 (10);
  BEGIN
    BEGIN
      SELECT NVL(MAX(item_exclusion_id)+1,1000)
      INTO l_item_exclusion_id
      FROM xxha_item_exclusion;
    END;
    BEGIN
      SELECT Country_Control_Id
      INTO l_Country_Control_Id
      FROM xxha_reg_country_control
      WHERE UPPER(country_code) = UPPER(P_Country_Code);
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
      raise_application_error (-20001, ' No Data Found For Country Code');
      l_status    := 'E';
      l_error_msg := SQLERRM;
    WHEN OTHERS THEN
      raise_application_error (-20001, SQLERRM);
      l_status    := 'E';
      l_error_msg := SQLERRM;
    END;
    BEGIN
      SELECT DISTINCT 
             msib.segment1,
             msib.description
      INTO   l_Item_Number,
             l_description
      FROM  mtl_system_items_b msib
      WHERE organization_id = 103
      AND   msib.segment1     = P_ITEM_NUMBER;
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
      raise_application_error (-20001, ' No Data Found For Item Number');
      l_status    := 'E';
      l_error_msg := SQLERRM;
    WHEN OTHERS THEN
      raise_application_error (-20001, SQLERRM);
      l_status    := 'E';
      l_error_msg := SQLERRM;
    END;
    BEGIN
      IF P_REG_END_DATE     IS NOT NULL THEN
        IF p_reg_start_date >= p_reg_end_date THEN
            raise_application_error (-20001, ' Effective Start Date entered should be less than Effective End Date.');
            l_status    := 'E';
            l_error_msg := SQLERRM;
        END IF;
      END IF;
    END;
    BEGIN
      SELECT COUNT(1)
      INTO l_item_active_flag
      FROM xxha_reg_country_control t1,
           xxha_item_exclusion t2
      WHERE t1.country_control_id   = t2.country_control_id
      AND   t1.country_control_id   = l_country_control_id
      AND   t1.country_code         = p_country_code
      AND   t2.item_number          = p_item_number
      AND ( P_Reg_Start_Date BETWEEN t2.item_exc_start_date AND NVL(t2.item_exc_end_date, '01-JAN-4977')
        --OR :XXHA_ITEM_REGISTRATION_B.item_reg_start_date < t2.item_reg_start_date
        )
      AND t2.item_exclusion_id <> NVL(l_item_exclusion_id , 0000);
        IF l_item_active_flag <> 0 THEN
            raise_application_error (-20001,'Effective Start Date entered overlaps with existing registration. Please enter different Date');
            l_status    := 'E';
            l_error_msg := SQLERRM;
      END IF;
    EXCEPTION
    WHEN OTHERS THEN
      raise_application_error (-20001, SQLERRM);
      l_status    := 'E';
      l_error_msg := SQLERRM;
    END;
    BEGIN
      IF  p_reg_end_date < p_reg_start_date THEN
          raise_application_error (-20001, ' Effective End Date entered is less than Effective start date.');
          l_status    := 'E';
          l_error_msg := SQLERRM;
      END IF;
    END;
    BEGIN
      SELECT COUNT(1)
      INTO l_item_active_flag
      FROM xxha_reg_country_control t1,
           xxha_item_exclusion t2
      WHERE t1.country_control_id              = t2.country_control_id
      AND   t1.country_control_id              = l_country_control_id
      AND   t1.country_code                    = p_country_code
      AND   t2.item_number                     = p_item_number
      AND   NVL(p_reg_end_date,'01-JAN-4977') >= NVL(t2.item_exc_start_date, '01-JAN-4977')
      AND   p_reg_start_date                  <= NVL(t2.item_exc_end_date, '01-JAN-4977')
      AND   t2.item_exclusion_id              <> NVL(l_item_exclusion_id, 0000000000000000001);
      
      IF l_item_active_flag <> 0 THEN
        raise_application_error (-20001,'Effective End Date entered overlaps with existing registration. Please enter different Date');
        l_status    := 'E';
        l_error_msg := SQLERRM;
      END IF;
      
    EXCEPTION
    WHEN OTHERS THEN
        raise_application_error (-20001, SQLERRM);
        l_status    := 'E';
        l_error_msg := SQLERRM;
    END;
      BEGIN
        SELECT COUNT(1)
        INTO l_item_exist_flag
        FROM xxha_item_registration t1
        WHERE Item_number      = P_Item_Number
        AND NVL(P_Reg_End_Date,'01-JAN-4977') >= NVL(t1.item_reg_start_date,'01-JAN-4977')
        AND P_Reg_Start_Date                  <= NVL(t1.item_reg_end_date,'01-JAN-4977')
      --  AND item_reg_end_date IS NULL
        AND Country_Control_Id = l_country_control_id;
        IF  l_item_exist_flag  <> 0 THEN
            raise_application_error (-20001,'Item exists in Haemo Item Registration.Please end date Item from Item Registration');
            l_status    := 'E';
            l_error_msg := SQLERRM;
        END IF;
        EXCEPTION
        WHEN OTHERS THEN
          raise_application_error (-20001, SQLERRM);
          l_status    := 'E';
          l_error_msg := SQLERRM;
      END;
    INSERT
    INTO xxha_item_exclusion
      (
        item_exclusion_id,
        item_number,
        item_description ,
        item_exc_start_date ,
        item_exc_end_date ,
        country_control_id,
        creation_date ,
        created_by ,
        last_update_date ,
        last_updated_by
      )
      VALUES
      (
        l_item_exclusion_id,
        l_item_number,
        l_description,
        p_reg_start_date ,
        p_reg_end_date ,
        l_country_control_id ,
        SYSDATE,
        fnd_profile.VALUE ('USER_ID'),
        SYSDATE,
        fnd_profile.VALUE ('USER_ID')
      );
  END;
  PROCEDURE LOAD_REGULATORY_CUSTOMER
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
    )
  IS
    l_Country_Control_Id      NUMBER;
    l_customer_reg_control_id NUMBER;
    l_cust_active_flag        NUMBER;
    l_country_code            VARCHAR2 (15);
    l_account_number          NUMBER;
    l_account_name            VARCHAR2 (200);
    l_error_msg               NUMBER DEFAULT NULL;
    l_status                  VARCHAR2 (10);
    l_error_flag              VARCHAR2 (10);
  BEGIN
    BEGIN
      SELECT NVL(MAX(customer_reg_control_id),1000)+1
      INTO l_customer_reg_control_id
      FROM xxha_customer_reg_control;
    END;
    BEGIN
      SELECT Country_Control_Id
      INTO   l_country_control_id
      FROM xxha_reg_country_control
      WHERE UPPER(country_code) = UPPER(P_Country_Code);
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
      raise_application_error (-20001, ' No Data Found For Country Code');
      l_status    := 'E';
      l_error_msg := SQLERRM;
    WHEN OTHERS THEN
      raise_application_error (-20001, SQLERRM);
      l_status    := 'E';
      l_error_msg := SQLERRM;
    END;
    BEGIN
      SELECT DISTINCT 
            d.account_number,
            e.party_name account_name
      INTO  l_account_number,
            l_account_name
      FROM  hz_cust_accounts d,
            hz_parties e
      WHERE d.party_id = e.party_id
      AND   d.account_number = P_Account_Number
      ORDER BY 1;
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
      raise_application_error (-20001, ' No Data Found For Customer Number');
      l_status    := 'E';
      l_error_msg := SQLERRM;
    WHEN OTHERS THEN
      raise_application_error (-20001, SQLERRM);
      l_status    := 'E';
      l_error_msg := SQLERRM;
    END;
    BEGIN
      IF P_CUST_REG_END_DATE     IS NOT NULL THEN
        IF P_CUST_REG_START_DATE >= P_CUST_REG_END_DATE THEN
          raise_application_error (-20001, ' Effective Start Date entered should be less than Effective End Date.');
          l_status    := 'E';
          l_error_msg := SQLERRM;
        END IF;
      END IF;
    END;
    BEGIN
      SELECT COUNT(1)
      INTO l_cust_active_flag
      FROM xxha_reg_country_control t1,
           xxha_customer_reg_control t2
      WHERE t1.country_control_id          = t2.country_control_id
      AND   t1.country_control_id          = l_country_control_id
      AND   t1.country_code                = p_country_code
      AND   t2.control_type                = p_control_type
      AND   t2.account_number              = p_account_number
      AND   NVL(t2.customer_type , 'xxyyzz') = NVL(p_customer_type , 'xxyyzz')
      AND   NVL(t2.scope_of_medical_device_lic , 'xxyyzz') = NVL(p_scope_of_medical_device_lic , 'xxyyzz')
        -- and T2.apl         like 'Y%'
      AND  (p_cust_reg_start_date BETWEEN t2.cust_reg_start_date AND NVL(t2.cust_reg_end_date, '01-JAN-4977'))
        --OR :XXHA_CUSTOMER_REG_CONTROL_B.CUST_REG_START_DATE < t2.CUST_REG_START_DATE
      AND  t2.customer_reg_control_id <> NVL(l_customer_reg_control_id, 0000);
      
       IF l_cust_active_flag <> 0 THEN
        raise_application_error (-20001,'Effective Start Date entered overlaps with existing registration. Please enter different Date');
        l_status    := 'E';
        l_error_msg := SQLERRM;
      END IF;
      
    EXCEPTION
    WHEN OTHERS THEN
    raise_application_error (-20001, SQLERRM);
    l_status := 'E';
    l_error_msg := SQLERRM;
    END;
    BEGIN
      IF p_cust_reg_end_date < p_cust_reg_start_date THEN
          raise_application_error (-20001, ' Effective End Date entered is less than Effective start date.');
          l_status    := 'E';
          l_error_msg := SQLERRM;
      END IF;
    END;
    BEGIN
      SELECT COUNT(1)
      INTO l_cust_active_flag
      FROM xxha_reg_country_control t1,
           xxha_customer_reg_control t2
      WHERE t1.country_control_id          = t2.country_control_id
      AND   t1.country_control_id          = l_country_control_id
      AND   t1.country_code                = p_country_code
      AND   t2.control_type                = p_control_type
      AND   t2.account_number              = p_account_number
      AND   NVL(t2.customer_type, 'xxyyzz')               = NVL(p_customer_type , 'xxyyzz')
      AND   NVL(t2.scope_of_medical_device_lic, 'xxyyzz') = NVL(p_scope_of_medical_device_lic , 'xxyyzz')
        --and T2.apl         like 'Y%'
      AND   p_cust_reg_end_date           >= NVL(t2.cust_reg_start_date, '01-JAN-4977')
      AND   p_cust_reg_start_date         <= NVL(t2.cust_reg_end_date, '01-JAN-4977')
      AND   t2.customer_reg_control_id    <> NVL(l_customer_reg_control_id, 00000000000001);
      
      IF l_cust_active_flag <> 0 THEN
        raise_application_error (-20001,'Effective End Date entered overlaps with existing registration. Please enter different Date');
        l_status    := 'E';
        l_error_msg := SQLERRM;
      END IF;
      EXCEPTION
      WHEN OTHERS THEN
        raise_application_error (-20001, SQLERRM);
        l_status := 'E';
        l_error_msg := SQLERRM;
    END;
    INSERT
    INTO xxha_customer_reg_control
      (
        customer_reg_control_id,
        account_number,
        account_name ,
        control_type ,
        regulatory_agency ,
        license_no,
        cust_reg_start_date ,
        cust_reg_end_date ,
        apl ,
        country_control_id,
        customer_type,
        scope_of_medical_device_lic,
        creation_date ,
        created_by ,
        last_update_date ,
        last_updated_by
      )
      VALUES
      (
        l_customer_reg_control_id,
        l_account_number,
        l_account_name ,
        p_control_type ,
        p_regulatory_agency ,
        p_license_no,
        p_cust_reg_start_date ,
        p_cust_reg_end_date ,
        p_apl ,
        l_country_control_id,
        p_customer_type,
        p_scope_of_medical_device_lic,
        SYSDATE,
        fnd_profile.VALUE ('USER_ID'),
        SYSDATE,
        fnd_profile.VALUE ('USER_ID')
      );
  END;
  PROCEDURE LOAD_REG_CUSTOMER_APPRV_LIST
    (
      P_ITEM_NUMBER             VARCHAR2,
      P_ITEM_DESCRIPTION        VARCHAR2,
      P_MEDICAL_DEVICE_CATEGORY VARCHAR2,
      P_APL_START_DATE          DATE,
      P_APL_END_DATE            DATE,
      P_CUSTOMER_NAME           VARCHAR2,
      P_COUNTRY_CODE            VARCHAR2
    )
  IS
    l_country_control_id      NUMBER;
    l_customer_reg_control_id NUMBER;
    l_customer_apl_id         NUMBER;
    l_cust_item_active_flag   NUMBER;
    l_item_number             NUMBER;
    l_item_description        VARCHAR2 (200);
    l_error_msg               NUMBER DEFAULT NULL;
    l_status                  VARCHAR2 (10);
    l_error_flag              VARCHAR2 (10);
  BEGIN
      BEGIN
        SELECT NVL(MAX(customer_apl_id),1000)+1
        INTO   l_customer_apl_id
        FROM xxha_customer_apprv_prod_list;
      END;
        BEGIN
          SELECT Country_Control_Id
          INTO   l_Country_Control_Id
          FROM xxha_reg_country_control
          WHERE UPPER(country_code) = UPPER(P_Country_Code);
        EXCEPTION
        WHEN NO_DATA_FOUND THEN
          raise_application_error (-20001, ' No Data Found For Country Code');
          l_status    := 'E';
          l_error_msg := SQLERRM;
        WHEN OTHERS THEN
          raise_application_error (-20001, SQLERRM);
          l_status    := 'E';
          l_error_msg := SQLERRM;
        END;
    BEGIN
      SELECT DISTINCT Customer_Reg_Control_Id
      INTO   l_customer_reg_control_id
      FROM   xxha_customer_reg_control
      WHERE  account_name       = P_Customer_Name
      AND    country_control_id = l_Country_Control_Id
      AND    apl LIKE 'Y%';
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
        raise_application_error (-20001, ' No Data Found For Customer Number');
        l_status    := 'E';
        l_error_msg := SQLERRM;
    WHEN OTHERS THEN
        raise_application_error (-20001, SQLERRM);
        l_status    := 'E';
        l_error_msg := SQLERRM;
    END;
    BEGIN
      SELECT DISTINCT 
             msib.segment1 Item,
             msib.description
      INTO   l_item_number,
             l_item_description
      FROM mtl_system_items_b msib,
           xxha_item_registration xir
      WHERE msib.organization_id = 103
      AND   msib.segment1          = xir.item_number
      AND   xir.country_control_id = l_country_control_id
      AND   msib.Segment1          = P_Item_Number;
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
          raise_application_error (-20001, ' No Data Found For Item Number in Regulatory master Data,Please register item for this country');
          l_status    := 'E';
          l_error_msg := SQLERRM;
    WHEN OTHERS THEN
          raise_application_error (-20001, SQLERRM);
          l_status    := 'E';
          l_error_msg := SQLERRM;
    END;
    BEGIN
      IF P_APL_END_DATE     IS NOT NULL THEN
        IF P_APL_START_DATE >= P_APL_END_DATE THEN
          raise_application_error (-20001,'Effective Start Date entered should be less than Effective End Date.');
          l_status    := 'E';
          l_error_msg := SQLERRM;
        END IF;
      END IF;
      SELECT COUNT(1)
      INTO l_cust_item_active_flag
      FROM xxha_customer_reg_control t1,
           xxha_customer_apprv_prod_list t2
      WHERE t1.customer_reg_control_id = t2.customer_reg_control_id
      AND   t1.customer_reg_control_id   = l_customer_reg_control_id
      AND   t2.item_number               = P_Item_Number
      AND  (P_Apl_Start_Date BETWEEN T2.apl_start_date AND NVL(T2.apl_end_date, '01-JAN-4977'))
        --OR :XXHA_CUST_APPRV_PROD_LIST_B.APL_START_DATE < T2.APL_START_DATE
      AND   t2.Customer_Apl_Id     <> NVL(l_customer_apl_id, 0000);
        IF l_cust_item_active_flag <> 0 THEN
           raise_application_error (-20001,'Effective Start Date entered overlaps with existing registration. Please enter different Date');
           l_status    := 'E';
           l_error_msg := SQLERRM;
        END IF;
      EXCEPTION
      WHEN OTHERS THEN
        raise_application_error (-20001, SQLERRM);
        l_status    := 'E';
        l_error_msg := SQLERRM;
    END;
    BEGIN
      IF P_APL_END_DATE < P_APL_START_DATE THEN
        raise_application_error (-20001,'Effective End Date entered is less than Effective start date.');
        l_status    := 'E';
        l_error_msg := SQLERRM;
      END IF;
      SELECT COUNT(1)
      INTO l_cust_item_active_flag
      FROM xxha_customer_reg_control t1,
           xxha_customer_apprv_prod_list t2
      WHERE t1.customer_reg_control_id   = t2.customer_reg_control_id
      AND   t1.customer_reg_control_id   = l_customer_reg_control_id
      AND   t2.item_number               = P_Item_Number
      AND   P_Apl_End_Date              >= NVL(t2.apl_start_date, '01-JAN-4977')
      AND   P_Apl_Start_Date            <= NVL(t2.apl_end_date, '01-JAN-4977')
      AND   t2.customer_apl_id          <> NVL(l_customer_apl_id, 00000000000001);
      
      IF l_cust_item_active_flag      <> 0 THEN
         raise_application_error (-20001,'Effective End Date entered overlaps with existing registration. Please enter different Date');
         l_status    := 'E';
         l_error_msg := SQLERRM;
      END IF;
      EXCEPTION
      WHEN OTHERS THEN
        raise_application_error (-20001, SQLERRM);
        l_status    := 'E';
        l_error_msg := SQLERRM;
    END;
    
    INSERT
    INTO xxha_customer_apprv_prod_list
      (
        customer_apl_id ,
        item_number ,
        item_description,
        medical_device_category,
        apl_start_date,
        apl_end_date ,
        customer_reg_control_id,
        creation_date ,
        created_by ,
        last_update_date ,
        last_updated_by
      )
      VALUES
      (
        l_customer_apl_id,
        l_item_number ,
        l_item_description,
        p_medical_device_category,
        p_apl_start_date,
        p_apl_end_date ,
        l_customer_reg_control_id,
        SYSDATE,
        fnd_profile.VALUE ('USER_ID'),
        SYSDATE,
        fnd_profile.VALUE ('USER_ID')
      );
  END;
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
      P_NEW_REGISTRATION_NUM          VARCHAR2    --Added by  praduman  on  14-Jul-2020 to  Update  Registration  Number
    )
  IS
    l_Country_Control_Id   NUMBER;
    l_Item_Registration_Id NUMBER;
    l_item_active_flag     NUMBER;
    l_country_code         VARCHAR2 (15);
    l_Item_Number          VARCHAR2 (100);
    l_description          VARCHAR2 (150);
    l_province             VARCHAR2 (150);
    l_error_msg            NUMBER DEFAULT NULL;
    l_status               VARCHAR2 (10);
    l_error_flag           VARCHAR2 (10);
    l_change_type          VARCHAR2 (20);
    l_active_flag          VARCHAR2 (5);
  BEGIN
    l_change_type := 'UPDATE';
    /*BEGIN
    SELECT MAX(item_registration_id)+1
    INTO l_Item_Registration_Id
    FROM xxha_item_registration;
    END;*/
    BEGIN
      SELECT Country_Control_Id
      INTO l_Country_Control_Id
      FROM xxha_reg_country_control
      WHERE UPPER(country_code) = UPPER(P_Country_Code);
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
      raise_application_error (-20001, ' No Data Found For Country Code');
      l_status    := 'E';
      l_error_msg := SQLERRM;
    WHEN OTHERS THEN
      raise_application_error (-20001, SQLERRM);
      l_status    := 'E';
      l_error_msg := SQLERRM;
    END;
    BEGIN
      IF P_REG_END_DATE     IS NOT NULL THEN
        IF P_REG_START_DATE >= P_REG_END_DATE THEN
          raise_application_error (-20001, ' Effective Start Date entered should be less than Effective End Date.');
          l_status    := 'E';
          l_error_msg := SQLERRM;
        END IF;
      END IF;
    END;
    BEGIN
      IF NVL(P_REG_END_DATE,SYSDATE) >= SYSDATE THEN
        l_active_flag := 'Y';
      ELSE
        l_active_flag := 'N';
      END IF;
    END;
    BEGIN
      IF P_REG_END_DATE < P_REG_START_DATE THEN
        raise_application_error (-20001, ' Effective End Date entered is less than Effective start date.');
        l_status    := 'E';
        l_error_msg := SQLERRM;
      END IF;
    END;
    /*Added by praduman on  14-jul-2020*/
      BEGIN
      IF P_NEW_REGISTRATION_NUM IS NOT NULL AND P_REGISTRATION_NUM IS NULL  THEN
        raise_application_error (-20001, 'Please enter Registration Number You want to Update in "REGISTRATION_NUM" Column');
        l_status    := 'E';
        l_error_msg := SQLERRM;
      END IF;
    END;
    /*End Added by praduman on  14-jul-2020*/
    BEGIN
      SELECT COUNT(1)
      INTO l_item_active_flag
      FROM xxha_reg_country_control t1,
           xxha_item_registration   t2
      WHERE t1.country_control_id                    = t2.country_control_id
      AND   t1.country_control_id                    = l_country_control_id
      AND   t1.country_code                          = P_Country_Code
      AND   t2.item_number                           = P_Item_Number
      AND   P_Reg_Start_Date    BETWEEN t2.item_reg_start_date AND NVL(t2.ITEM_REG_END_DATE,'01-JAN-4977')
    --  AND   NVL(t2.item_reg_end_date,'01-JAN-4977') <= NVL(P_Reg_End_Date,NVL(t2.item_reg_end_date,'01-JAN-4977'))
     -- AND   NVL(manufacturing_site,1)                = NVL(P_Manufacturing_Site,NVL(Manufacturing_Site,1))
      AND   t2.registration_num                      = NVL(P_Registration_Num,t2.registration_num);
      
      IF l_item_active_flag    <> 0  AND P_NEW_REGISTRATION_NUM IS NOT NULL  THEN
        UPDATE xxha_item_registration t1
        SET regulatory_agency           = NVL(P_Regulatory_Agency,regulatory_agency),
          REGISTRATION_NUM =  P_NEW_REGISTRATION_NUM ,--Added  by  praduman  14-jul-2020
          --ITEM_REG_START_DATE = P_REG_START_DATE ,
          item_reg_end_date             = NVL(P_Reg_End_Date,item_reg_end_date),
          registered_legal_entity       = NVL(P_Registered_Legal_Entity,registered_legal_entity),
          manufacturing_site            = NVL(P_Manufacturing_Site,manufacturing_site),
          item_name_local_language      = NVL(P_Item_Name_Local_Language,item_name_local_language),
          packing_std_equip_model       = NVL(P_Packing_Std_Equip_Model,packing_std_equip_model),
          category_code                 = NVL(P_Category_Code,category_code),
          active_flag                   = l_active_flag,
          last_update_date              = SYSDATE,
          last_updated_by               = fnd_profile.VALUE ('USER_ID')
        WHERE t1.country_control_id     = l_country_control_id
        AND   t1.item_number              = P_Item_Number
        AND   P_Reg_Start_Date   BETWEEN t1.item_reg_start_date AND NVL(T1.ITEM_REG_END_DATE,'01-JAN-4977')
          --AND   NVL(T2.ITEM_REG_END_DATE,'01-JAN-4977') = NVL(P_REG_END_DATE,NVL(T2.ITEM_REG_END_DATE,'01-JAN-4977'))
       -- AND   NVL(manufacturing_site,1)   = NVL(P_Manufacturing_Site,NVL(manufacturing_site,1))
        AND   t1.registration_num         = NVL(P_Registration_Num,t1.registration_num);
      ELSE IF
          l_item_active_flag    <> 0 AND P_NEW_REGISTRATION_NUM IS NULL  THEN
        UPDATE xxha_item_registration t1
        SET regulatory_agency           = NVL(P_Regulatory_Agency,regulatory_agency),
          item_reg_end_date             = NVL(P_Reg_End_Date,item_reg_end_date),
          registered_legal_entity       = NVL(P_Registered_Legal_Entity,registered_legal_entity),
          manufacturing_site            = NVL(P_Manufacturing_Site,manufacturing_site),
          item_name_local_language      = NVL(P_Item_Name_Local_Language,item_name_local_language),
          packing_std_equip_model       = NVL(P_Packing_Std_Equip_Model,packing_std_equip_model),
          category_code                 = NVL(P_Category_Code,category_code),
          active_flag                   = l_active_flag,
          last_update_date              = SYSDATE,
          last_updated_by               = fnd_profile.VALUE ('USER_ID')
        WHERE t1.country_control_id     = l_country_control_id
        AND   t1.item_number              = P_Item_Number
        AND   P_Reg_Start_Date   BETWEEN t1.item_reg_start_date AND NVL(T1.ITEM_REG_END_DATE,'01-JAN-4977')
          --AND   NVL(T2.ITEM_REG_END_DATE,'01-JAN-4977') = NVL(P_REG_END_DATE,NVL(T2.ITEM_REG_END_DATE,'01-JAN-4977'))
       -- AND   NVL(manufacturing_site,1)   = NVL(P_Manufacturing_Site,NVL(manufacturing_site,1))
        AND   t1.registration_num         = NVL(P_Registration_Num,t1.registration_num);
      ELSE
        raise_application_error (-20001,'Record does not exists for update Please Insert the record');
        l_status    := 'E';
        l_error_msg := SQLERRM;
      END IF;
      END IF;
    END;
  END;
  PROCEDURE UPDATE_ITEM_EXCLUSION
    (
      P_ITEM_NUMBER              VARCHAR2,
      P_ITEM_DESCRIPTION         VARCHAR2,
      P_REG_START_DATE           DATE,
      P_REG_END_DATE             DATE,
      P_COUNTRY_CODE             VARCHAR2
    )
  IS
    l_Country_Control_Id   NUMBER;
    l_item_active_flag     NUMBER;
    l_country_code         VARCHAR2 (15);
    l_error_msg            NUMBER DEFAULT NULL;
    l_status               VARCHAR2 (10);
    l_error_flag           VARCHAR2 (10);
    l_active_flag          VARCHAR2 (5);
  BEGIN
    BEGIN
      SELECT Country_Control_Id
      INTO l_Country_Control_Id
      FROM xxha_reg_country_control
      WHERE UPPER(country_code) = UPPER(P_Country_Code);
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
      raise_application_error (-20001, 'No Data Found For Country Code');
      l_status    := 'E';
      l_error_msg := SQLERRM;
    WHEN OTHERS THEN
      raise_application_error (-20001, SQLERRM);
      l_status    := 'E';
      l_error_msg := SQLERRM;
    END;
    BEGIN
      IF P_REG_END_DATE     IS NOT NULL THEN
        IF P_REG_START_DATE >= P_REG_END_DATE THEN
          raise_application_error (-20001, ' Effective Start Date entered should be less than Effective End Date.');
          l_status    := 'E';
          l_error_msg := SQLERRM;
        END IF;
      END IF;
    END;
    BEGIN
      IF NVL(P_REG_END_DATE,SYSDATE) >= SYSDATE THEN
        l_active_flag := 'Y';
      ELSE
        l_active_flag := 'N';
      END IF;
    END;
    BEGIN
      IF P_REG_END_DATE < P_REG_START_DATE THEN
        raise_application_error (-20001, ' Effective End Date entered is less than Effective start date.');
        l_status    := 'E';
        l_error_msg := SQLERRM;
      END IF;
    END;
    BEGIN
      SELECT COUNT(1)
      INTO l_item_active_flag
      FROM xxha_reg_country_control t1,
           xxha_item_exclusion   t2
      WHERE t1.country_control_id                    = t2.country_control_id
      AND   t1.country_control_id                    = l_country_control_id
      AND   t1.country_code                          = P_Country_Code
      AND   t2.item_number                           = P_Item_Number
      AND   P_Reg_Start_Date between t2.item_exc_start_date and nvl(t2.item_exc_end_date, '01-JAN-4977') ;
      
      IF l_item_active_flag  <> 0  THEN
        UPDATE xxha_item_exclusion t1
        SET item_exc_end_date             = NVL(P_Reg_End_Date,item_exc_end_date),
            active_flag                   = l_active_flag,
            last_update_date              = SYSDATE,
            last_updated_by               = fnd_profile.VALUE ('USER_ID')
        WHERE t1.country_control_id       = l_country_control_id
        AND   t1.item_number              = P_Item_Number
        AND   P_Reg_Start_Date between t1.item_exc_start_date and nvl(t1.item_exc_end_date, '01-JAN-4977') ;
      ELSE
        raise_application_error (-20001,'Record does not exists for update Please Insert the record');
        l_status    := 'E';
        l_error_msg := SQLERRM;
      END IF;
    END;
  END;
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
    )
  IS
   l_Country_Control_Id      NUMBER;
    l_cust_active_flag        NUMBER;
    l_country_code            VARCHAR2 (15);
    l_account_number          NUMBER;
    l_account_name            VARCHAR2 (200);
    l_error_msg               NUMBER DEFAULT NULL;
    l_status                  VARCHAR2 (10);
    l_error_flag              VARCHAR2 (10);
  BEGIN
    BEGIN
      SELECT Country_Control_Id
      INTO   l_country_control_id
      FROM xxha_reg_country_control
      WHERE UPPER(country_code) = UPPER(P_Country_Code);
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
      raise_application_error (-20001, ' No Data Found For Country Code');
      l_status    := 'E';
      l_error_msg := SQLERRM;
    WHEN OTHERS THEN
      raise_application_error (-20001, SQLERRM);
      l_status    := 'E';
      l_error_msg := SQLERRM;
    END;
    BEGIN
      SELECT DISTINCT 
            d.account_number,
            e.party_name account_name
      INTO  l_account_number,
            l_account_name
      FROM  hz_cust_accounts d,
            hz_parties e
      WHERE d.party_id = e.party_id
      AND   d.account_number = P_Account_Number
      ORDER BY 1;
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
      raise_application_error (-20001, ' No Data Found For Customer Number');
      l_status    := 'E';
      l_error_msg := SQLERRM;
    WHEN OTHERS THEN
      raise_application_error (-20001, SQLERRM);
      l_status    := 'E';
      l_error_msg := SQLERRM;
    END;
    BEGIN
      IF P_CUST_REG_END_DATE     IS NOT NULL THEN
        IF P_CUST_REG_START_DATE >= P_CUST_REG_END_DATE THEN
          raise_application_error (-20001, ' Effective Start Date entered should be less than Effective End Date.');
          l_status    := 'E';
          l_error_msg := SQLERRM;
        END IF;
      END IF;
    END;
    BEGIN
    SELECT COUNT(1)
      INTO l_cust_active_flag
      FROM xxha_reg_country_control t1,
           xxha_customer_reg_control t2
      WHERE t1.country_control_id          = t2.country_control_id
      AND   t1.country_control_id          = l_country_control_id
      AND   t1.country_code                = p_country_code
      AND   t2.control_type                = p_control_type
      AND   t2.account_number              = p_account_number
    --  AND  NVL(t2.customer_type,'xxyyzz')  = NVL(p_customer_type ,NVL(t2.customer_type,'xxyyzz'))
     -- AND  NVL(t2.scope_of_medical_device_lic, 'xxyyzz') = NVL(p_scope_of_medical_device_lic ,NVL(t2.scope_of_medical_device_lic, 'xxyyzz'))
        -- and T2.apl         like 'Y%'
      AND  (p_cust_reg_start_date BETWEEN t2.cust_reg_start_date AND NVL(t2.cust_reg_end_date, '01-JAN-4977'));
        --OR :XXHA_CUSTOMER_REG_CONTROL_B.CUST_REG_START_DATE < t2.CUST_REG_START_DATE
      
     /*  IF l_cust_active_flag <> 0 THEN
        raise_application_error (-20001,'Effective Start Date entered overlaps with existing registration. Please enter different Date');
        l_status    := 'E';
        l_error_msg := SQLERRM;
      END IF;*/
      
    EXCEPTION
    WHEN OTHERS THEN
    raise_application_error (-20001, SQLERRM);
    l_status := 'E';
    l_error_msg := SQLERRM;
    END;
    BEGIN
      IF p_cust_reg_end_date < p_cust_reg_start_date THEN
          raise_application_error (-20001, ' Effective End Date entered is less than Effective start date.');
          l_status    := 'E';
          l_error_msg := SQLERRM;
      END IF;
    END;
    BEGIN
      SELECT COUNT(1)
      INTO l_cust_active_flag
      FROM xxha_reg_country_control t1,
           xxha_customer_reg_control t2
      WHERE t1.country_control_id          = t2.country_control_id
      AND   t1.country_control_id          = l_country_control_id
      AND   t1.country_code                = p_country_code
      AND   t2.control_type                = p_control_type
      AND   t2.account_number              = p_account_number
     -- AND   NVL(t2.customer_type,'xxyyzz')  = NVL(p_customer_type ,NVL(t2.customer_type,'xxyyzz'))
     -- AND   NVL(t2.scope_of_medical_device_lic, 'xxyyzz') = NVL(p_scope_of_medical_device_lic ,NVL(t2.scope_of_medical_device_lic, 'xxyyzz'))
        --and T2.apl         like 'Y%'
     -- AND   p_cust_reg_end_date           >= NVL(t2.cust_reg_start_date, '01-JAN-4977')
       AND  (p_cust_reg_start_date BETWEEN t2.cust_reg_start_date AND NVL(t2.cust_reg_end_date, '01-JAN-4977'));
      --AND   t2.customer_reg_control_id    <> NVL(l_customer_reg_control_id, 00000000000001);
      
     /* IF l_cust_active_flag <> 0 THEN
        raise_application_error (-20001,'Effective End Date entered overlaps with existing registration. Please enter different Date1');
        l_status    := 'E';
        l_error_msg := SQLERRM;*/
--      END IF;
      EXCEPTION
      WHEN OTHERS THEN
        raise_application_error (-20001, SQLERRM);
        l_status := 'E';
        l_error_msg := SQLERRM;
    END;
      
      IF l_cust_active_flag  <> 0  THEN
        UPDATE xxha_customer_reg_control t1
        SET cust_reg_end_date             = NVL(p_cust_reg_end_date,cust_reg_end_date),
            regulatory_agency             = NVL(p_regulatory_agency,regulatory_agency),
            license_no                    = NVL(p_license_no,license_no),
            apl                           = NVL(p_apl,apl),
            customer_type                 = NVL(p_customer_type,customer_type),
            scope_of_medical_device_lic   = NVL(p_scope_of_medical_device_lic,scope_of_medical_device_lic),
            last_update_date              = SYSDATE,
            last_updated_by               = fnd_profile.VALUE ('USER_ID')
        WHERE t1.country_control_id       = l_country_control_id
        AND   t1.control_type             = p_control_type
        AND   t1.account_number           = p_account_number
        AND   (p_cust_reg_start_date BETWEEN t1.cust_reg_start_date AND NVL(t1.cust_reg_end_date, '01-JAN-4977')) ;
      ELSE
        raise_application_error (-20001,'Record does not exists for update Please Insert the record');
        l_status    := 'E';
        l_error_msg := SQLERRM;
      END IF;
    END;
    PROCEDURE UPDATE_REG_CUSTOMER_APPRV_LIST
    (
      P_ITEM_NUMBER             VARCHAR2,
      P_ITEM_DESCRIPTION        VARCHAR2,
      P_MEDICAL_DEVICE_CATEGORY VARCHAR2,
      P_APL_START_DATE          DATE,
      P_APL_END_DATE            DATE,
      P_CUSTOMER_NAME           VARCHAR2,
      P_COUNTRY_CODE            VARCHAR2
    )
  IS
    l_country_control_id      NUMBER;
    l_customer_reg_control_id NUMBER;
    l_cust_item_active_flag   NUMBER;
    l_item_number             NUMBER;
    l_item_description        VARCHAR2 (200);
    l_error_msg               NUMBER DEFAULT NULL;
    l_status                  VARCHAR2 (10);
    l_error_flag              VARCHAR2 (10);
  BEGIN
        BEGIN
          SELECT Country_Control_Id
          INTO   l_Country_Control_Id
          FROM xxha_reg_country_control
          WHERE UPPER(country_code) = UPPER(P_Country_Code);
        EXCEPTION
        WHEN NO_DATA_FOUND THEN
          raise_application_error (-20001, ' No Data Found For Country Code');
          l_status    := 'E';
          l_error_msg := SQLERRM;
        WHEN OTHERS THEN
          raise_application_error (-20001, SQLERRM);
          l_status    := 'E';
          l_error_msg := SQLERRM;
        END;
    BEGIN
      SELECT DISTINCT Customer_Reg_Control_Id
      INTO   l_customer_reg_control_id
      FROM   xxha_customer_reg_control
      WHERE  account_name       = P_Customer_Name
      AND    country_control_id = l_Country_Control_Id
      AND    apl LIKE 'Y%';
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
        raise_application_error (-20001, ' No Data Found For Customer Number');
        l_status    := 'E';
        l_error_msg := SQLERRM;
    WHEN OTHERS THEN
        raise_application_error (-20001, SQLERRM);
        l_status    := 'E';
        l_error_msg := SQLERRM;
    END;
    BEGIN
      SELECT DISTINCT 
             msib.segment1 Item,
             msib.description
      INTO   l_item_number,
             l_item_description
      FROM mtl_system_items_b msib,
           xxha_item_registration xir
      WHERE msib.organization_id = 103
      AND   msib.segment1          = xir.item_number
      AND   xir.country_control_id = l_country_control_id
      AND   msib.Segment1          = P_Item_Number;
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
          raise_application_error (-20001, ' No Data Found For Item Number in Regulatory master Data,Please register item for this country');
          l_status    := 'E';
          l_error_msg := SQLERRM;
    WHEN OTHERS THEN
          raise_application_error (-20001, SQLERRM);
          l_status    := 'E';
          l_error_msg := SQLERRM;
    END;
    BEGIN
      IF P_APL_END_DATE     IS NOT NULL THEN
        IF P_APL_START_DATE >= P_APL_END_DATE THEN
          raise_application_error (-20001,'Effective Start Date entered should be less than Effective End Date.');
          l_status    := 'E';
          l_error_msg := SQLERRM;
        END IF;
      END IF;
      SELECT COUNT(1)
      INTO l_cust_item_active_flag
      FROM xxha_customer_reg_control t1,
           xxha_customer_apprv_prod_list t2
      WHERE t1.customer_reg_control_id = t2.customer_reg_control_id
      AND   t1.customer_reg_control_id   = l_customer_reg_control_id
      AND   t2.item_number               = P_Item_Number
      AND  (P_Apl_Start_Date BETWEEN T2.apl_start_date AND NVL(T2.apl_end_date, '01-JAN-4977'));
        --OR :XXHA_CUST_APPRV_PROD_LIST_B.APL_START_DATE < T2.APL_START_DATE
        IF l_cust_item_active_flag <> 0 THEN
           raise_application_error (-20001,'Effective Start Date entered overlaps with existing registration. Please enter different Date');
           l_status    := 'E';
           l_error_msg := SQLERRM;
        END IF;
      EXCEPTION
      WHEN OTHERS THEN
        raise_application_error (-20001, SQLERRM);
        l_status    := 'E';
        l_error_msg := SQLERRM;
    END;
    BEGIN
      IF P_APL_END_DATE < P_APL_START_DATE THEN
        raise_application_error (-20001,'Effective End Date entered is less than Effective start date.');
        l_status    := 'E';
        l_error_msg := SQLERRM;
      END IF;
      SELECT COUNT(1)
      INTO l_cust_item_active_flag
      FROM xxha_customer_reg_control t1,
           xxha_customer_apprv_prod_list t2
      WHERE t1.customer_reg_control_id   = t2.customer_reg_control_id
      AND   t1.customer_reg_control_id   = l_customer_reg_control_id
      AND   t2.item_number               = P_Item_Number
      AND   P_Apl_End_Date              >= NVL(t2.apl_start_date, '01-JAN-4977')
      AND   P_Apl_Start_Date            <= NVL(t2.apl_end_date, '01-JAN-4977');
     -- AND   t2.customer_apl_id          <> NVL(l_customer_apl_id, 00000000000001);
      
      IF l_cust_item_active_flag      <> 0 THEN
         raise_application_error (-20001,'Effective End Date entered overlaps with existing registration. Please enter different Date');
         l_status    := 'E';
         l_error_msg := SQLERRM;
      END IF;
      EXCEPTION
      WHEN OTHERS THEN
        raise_application_error (-20001, SQLERRM);
        l_status    := 'E';
        l_error_msg := SQLERRM;
    END;
      IF l_cust_item_active_flag  <> 0  THEN
      UPDATE xxha_customer_apprv_prod_list t1
        SET medical_device_category       = NVL(p_medical_device_category,medical_device_category),
            apl_end_date                  = NVL( p_apl_end_date,apl_end_date),
            last_update_date              = SYSDATE,
            last_updated_by               = fnd_profile.VALUE ('USER_ID')
        WHERE 1=1--t1.country_control_id       = l_country_control_id
        AND   t1.customer_reg_control_id  = l_customer_reg_control_id
        AND   t1.item_number              = P_Item_Number
        AND  (P_Apl_Start_Date BETWEEN T1.apl_start_date AND NVL(T1.apl_end_date, '01-JAN-4977')) ;
      ELSE
        raise_application_error (-20001,'Record does not exists for update Please Insert the record');
        l_status    := 'E';
        l_error_msg := SQLERRM;
      END IF;
    END;
END;