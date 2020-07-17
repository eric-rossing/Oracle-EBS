create or replace PACKAGE BODY XXHA_REG_COUNTRY_DATA_PKG
AS
PROCEDURE validate_data(p_batch_id  IN NUMBER)
IS
v_validate_reg_data   g_tab_rec_data;
v_count               NUMBER:=0;
l_error_msg	       VARCHAR2(32000);
l_country_active_flag number;
l_status  VARCHAR2(10);
l_territory_code  VARCHAR2(10);
l_territory_name  VARCHAR2(255);
BEGIN

 SELECT *
	BULK COLLECT
	INTO v_validate_reg_data
	FROM  xxha_reg_country_control_stg
   WHERE 1=1
   AND process_flag   = 'N'
	 AND batch_id       = p_batch_id;
   
FOR rec_stg IN v_validate_reg_data.FIRST ..v_validate_reg_data.LAST
	LOOP
		 l_error_msg := NULL;
     l_status  := NULL;
	 BEGIN
      SELECT DISTINCT territory_code code
      INTO l_territory_code
      FROM fnd_territories_tl
      WHERE language                   = 'US'
      AND UPPER( territory_short_name) =upper(v_validate_reg_data(rec_stg).country);
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
      l_status    := 'E';
      l_error_msg := 'No Data Found For Country Code';
      -- DBMS_OUTPUT.PUT_LINE( 'Line No '|| v_validate_reg_data(rec_stg).country_control_id||'Country code'||upper(v_validate_reg_data(rec_stg).country)|| l_error_msg);
    WHEN OTHERS THEN
      l_status    := 'E';
      l_error_msg := SQLERRM;
    END;
      BEGIN
      SELECT DISTINCT territory_short_name
      into l_territory_name
      FROM fnd_territories_tl
      WHERE language                   = 'US'
      AND UPPER( territory_code)       =upper(v_validate_reg_data(rec_stg).country_code)
      AND UPPER( territory_short_name) =upper(v_validate_reg_data(rec_stg).country);
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
      l_status    := 'E';
      l_error_msg := l_error_msg ||' No Data Found For Country';
    --  DBMS_OUTPUT.PUT_LINE( 'Line No '|| v_validate_reg_data(rec_stg).country_control_id||'Country'||upper(v_validate_reg_data(rec_stg).country_code)|| l_error_msg);
    WHEN OTHERS THEN
      l_status    := 'E';
      l_error_msg := l_error_msg ||SQLERRM;
    END;
	  BEGIN
      SELECT COUNT(1)
      INTO l_country_active_flag
      FROM XXHA_REG_COUNTRY_CONTROL T1
      WHERE 1                   =1
      AND UPPER(T1.COUNTRY)            = upper(v_validate_reg_data(rec_stg).country)
      AND NVL(T1.STATE,'XX')    = NVL(STATE, NVL(T1.STATE,'XX'))
      AND NVL(T1.PROVINCE,'XX') = NVL(PROVINCE, NVL(T1.PROVINCE,'XX'));
      IF l_country_active_flag  > 0  THEN
        l_status    := 'U';--'E';
        l_error_msg := l_error_msg ||' Record for entered Country already exists.';
      --   DBMS_OUTPUT.PUT_LINE( 'Line No '|| v_validate_reg_data(rec_stg).country_control_id||'Country '||upper(v_validate_reg_data(rec_stg).country)|| l_error_msg);
      END IF;
    END;
	begin
	IF l_status = 'E' THEN
	UPDATE xxha_reg_country_control_stg
			   SET process_flag      = 'E',
				   error_message     = l_error_msg,
				   last_update_date  = SYSDATE
			 WHERE UPPER(country_code)             = upper(v_validate_reg_data(rec_stg).country_code)
			   AND UPPER(country) =upper(v_validate_reg_data(rec_stg).country)
			   AND process_flag          = 'N'
			   AND batch_id              = p_batch_id;
	    END IF;
      IF l_status = 'U' THEN
      UPDATE xxha_reg_country_control_stg
			   SET INSERT_ALLOWED      = 'N',
				     error_message     = l_error_msg,
				     last_update_date  = SYSDATE
			 WHERE UPPER(country_code)             = upper(v_validate_reg_data(rec_stg).country_code)
			   AND UPPER(country) =upper(v_validate_reg_data(rec_stg).country)
			   AND process_flag          = 'N'
			   AND batch_id              = p_batch_id;
	    END IF;
	end;
  v_count:= v_count + SQL%ROWCOUNT;
	END LOOP;
COMMIT;
--DBMS_OUTPUT.PUT_LINE( 'Total no of Record Processed' || v_count);
EXCEPTION
WHEN OTHERS THEN
DBMS_OUTPUT.PUT_LINE( 'Error while validating the staging records - SQLERRM -' || SQLERRM);
-- DBMS_OUTPUT.PUT_LINE( 'Country '||upper(v_validate_reg_data(rec_stg).country)|| l_error_msg);
RAISE;
END validate_data;
PROCEDURE validate_Item_inclusion_data(p_batch_id  IN NUMBER
                                       ,p_country_code IN VARCHAR2)   --praduman
IS
v_validate_reg_data   g_tab_iteminc_data;
v_count               NUMBER:=0;
l_error_msg	       VARCHAR2(32000);
l_item_active_flag  number;
l_status  VARCHAR2(10);
l_territory_name  VARCHAR2(100);
l_Country_Control_Id  VARCHAR2(255);
l_Item_Number          VARCHAR2 (100);
l_description          VARCHAR2 (300);
l_active_flag varchar2(5);
BEGIN

 SELECT *
	BULK COLLECT
	INTO v_validate_reg_data
	FROM  xxha_item_registration_stg
   WHERE 1=1
   AND process_flag   = 'N'
   AND Country_code =  p_country_code   --praduman
	 AND batch_id       = p_batch_id;
   
FOR rec_stg IN v_validate_reg_data.FIRST ..v_validate_reg_data.LAST
	LOOP
		 l_error_msg := NULL;
         l_status  := NULL;
      BEGIN
      SELECT DISTINCT territory_short_name
      into l_territory_name
      FROM fnd_territories_tl
      WHERE language                   = 'US'
      AND UPPER(territory_code)       =upper(v_validate_reg_data(rec_stg).country_code);
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
      l_status    := 'E';
      l_error_msg := l_error_msg ||' No Data Found For Country';
    --  DBMS_OUTPUT.PUT_LINE( 'Line No '|| v_validate_reg_data(rec_stg).country_control_id||'Country'||upper(v_validate_reg_data(rec_stg).country_code)|| l_error_msg);
    WHEN OTHERS THEN
      l_status    := 'E';
      l_error_msg := SQLERRM;
   --   DBMS_OUTPUT.PUT_LINE( 'START1');
    END;
	 BEGIN
      SELECT Country_Control_Id
      INTO l_Country_Control_Id
      FROM XXHA_REG_COUNTRY_CONTROL
      WHERE UPPER(country_code) = upper(v_validate_reg_data(rec_stg).country_code);
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
      l_status    := 'E';
       l_error_msg := l_error_msg ||'Country code Invalid';
    WHEN OTHERS THEN
      l_status    := 'E';
      l_error_msg := SQLERRM;
    --  DBMS_OUTPUT.PUT_LINE( 'START2');
    END;
	 BEGIN
      SELECT DISTINCT msib.SEGMENT1,
        msib.DESCRIPTION
      INTO l_Item_Number,
        l_description
      FROM MTL_SYSTEM_ITEMS_B msib
      WHERE ORGANIZATION_ID = 103
     AND segment1     = v_validate_reg_data(rec_stg).item_number;
     -- AND REGEXP_REPLACE(segment1, '[^0-9A-Za-z]', ' ')     = REGEXP_REPLACE(RTRIM(v_validate_reg_data(rec_stg).item_number), '[^0-9A-Za-z]', ' ');
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
      l_status    := 'E';
       l_error_msg := l_error_msg ||'Item Code Invalid';
    WHEN OTHERS THEN
      l_status    := 'E';
      l_error_msg := SQLERRM;
      DBMS_OUTPUT.PUT_LINE( 'START3');
    END;
	 BEGIN
      IF v_validate_reg_data(rec_stg).item_reg_end_date  IS NOT NULL THEN
        IF v_validate_reg_data(rec_stg).item_reg_start_date > v_validate_reg_data(rec_stg).item_reg_end_date THEN
          l_status    := 'E';
          l_error_msg := l_error_msg ||' Effective Start Date entered should be less than Effective End Date.';
        END IF;
      END IF;
    END;
	 begin
   IF nvl(v_validate_reg_data(rec_stg).item_reg_end_date,sysdate) >= sysdate 
	THEN
	l_active_flag := 'Y';
else
 	l_active_flag := 'N';	
END IF;
   end;
	  BEGIN
       SELECT COUNT(1)
      INTO l_item_active_flag
      FROM XXHA_REG_COUNTRY_CONTROL T1,
        XXHA_ITEM_REGISTRATION T2
      WHERE T1.COUNTRY_CONTROL_ID = T2.COUNTRY_CONTROL_ID
      AND T1.COUNTRY_CONTROL_ID   = l_COUNTRY_CONTROL_ID
      AND UPPER(T1.COUNTRY_CODE)              = upper(v_validate_reg_data(rec_stg).country_code)
      AND T2.ITEM_NUMBER          = l_Item_Number--v_validate_reg_data(rec_stg).item_number
      AND NVL(v_validate_reg_data(rec_stg).item_reg_end_date, '01-JAN-4977') >= NVL(T2.item_reg_start_date, '01-JAN-4977')
      AND v_validate_reg_data(rec_stg).item_reg_start_date <= NVL(T2.ITEM_REG_END_DATE, '01-JAN-4977');
      IF l_item_active_flag  > 0 AND v_validate_reg_data(rec_stg).INSERT_ALLOWED = 'Y'  THEN
        l_status    := 'E';
        l_error_msg := l_error_msg ||'Effective Start Date entered overlaps with existing registration. Please enter different Date';
      END IF;
	   IF l_item_active_flag  = 0 AND v_validate_reg_data(rec_stg).INSERT_ALLOWED = 'N'  THEN
        l_status    := 'E';
        l_error_msg := l_error_msg ||'Record does not exists for update the data'||l_Item_Number;
      END IF;
    END;
	begin
	IF l_status = 'E' THEN
	UPDATE xxha_item_registration_stg
			   SET process_flag      = 'E',
				   error_message     = l_error_msg,
				   last_update_date  = SYSDATE,
				   country_control_id = l_Country_Control_Id
			 WHERE UPPER(country_code)             = upper(v_validate_reg_data(rec_stg).country_code)
			   AND item_number =v_validate_reg_data(rec_stg).item_number
			   AND process_flag          = 'N'
			   AND batch_id              = p_batch_id;
	    END IF;
      COMMIT;
      IF l_status is null THEN
      UPDATE xxha_item_registration_stg
			   SET country_control_id = l_Country_Control_Id,
			       item_description = l_description,
             --item_number = l_item_number,    --PRADUMAN
             active_flag = l_active_flag,
             process_flag          = 'V'          --PRADUMAN
			 WHERE UPPER(country_code)             = upper(v_validate_reg_data(rec_stg).country_code)
			   AND item_number =v_validate_reg_data(rec_stg).item_number
			   AND process_flag          = 'N'
			   AND batch_id              = p_batch_id;
	    END IF;
      COMMIT;
	end;
  --v_count:= v_count + SQL%ROWCOUNT;
  COMMIT;
	END LOOP;
  v_validate_reg_data.delete;
COMMIT;
--DBMS_OUTPUT.PUT_LINE( 'Total no of Record Processed' || v_count);
EXCEPTION
WHEN OTHERS THEN
DBMS_OUTPUT.PUT_LINE( 'Error while validating the staging records - SQLERRM -' || SQLERRM);
DBMS_OUTPUT.PUT_LINE( 'Records Not Exist in Staging Table');
-- DBMS_OUTPUT.PUT_LINE( 'Country '||upper(v_validate_reg_data(rec_stg).country)|| l_error_msg);
--RAISE;
END validate_Item_inclusion_data;
PROCEDURE main_proc (
	p_user_id      IN    NUMBER,
	p_request_id   IN    NUMBER,
	p_file_name    IN    VARCHAR2,
	p_source       IN    VARCHAR2,
	p_batch_id     IN    NUMBER
) IS
	v_rec_data       g_tab_rec_data;
	v_cnt                NUMBER :=0;
  v_error_cnt          NUMBER :=0;
	v_request_id         NUMBER;
	v_resp_id            NUMBER;
	v_resp_appl_id       NUMBER;
	v_insert_allowed     VARCHAR2(1) := NULL;
	v_data_retain        NUMBER;
	v_item_id            NUMBER;
	v_rowcnt             NUMBER :=0;
	v_error_message      VARCHAR2(32000);
BEGIN
	g_batch_id := p_batch_id;
	DBMS_OUTPUT.PUT_LINE( 'Start of the Regulatory Header Upload program');

	BEGIN
	  UPDATE xxha_reg_country_control_stg
		 SET batch_id           = g_batch_id,
			 request_id         = p_request_id,
			 file_name          = p_file_name,
			 created_by         = p_user_id,          
			 last_updated_by    = p_user_id
	  WHERE 1=1
		AND batch_source   = p_source
		AND process_flag   = 'N'
		AND batch_id IS NULL;

	--DBMS_OUTPUT.PUT_LINE( 'Updating batch id to staging table xxha_reg_country_control_stg :' || g_batch_id);
	COMMIT;
	EXCEPTION WHEN OTHERS THEN
	--	DBMS_OUTPUT.PUT_LINE( 'Error while updating batch id - SQLERRM -' || SQLERRM);
   DBMS_OUTPUT.PUT_LINE('Error while updating batch id - SQLERRM -' || SQLERRM);
		RAISE;
	END;

	BEGIN
	   FOR rec_dup IN (SELECT xrcc.*
						 FROM xxha_reg_country_control_stg xrcc
							  ,(SELECT country,country_code, COUNT(*)
								 FROM xxha_reg_country_control_stg
								WHERE 1=1
								  AND batch_id     = g_batch_id
								  AND process_flag = 'N'
								GROUP BY country,country_code
							   HAVING COUNT(*) > 1 ) dup
						WHERE xrcc.country_code = dup.country_code
						  AND xrcc.country         = dup.country
						  AND xrcc.batch_id          = g_batch_id
						  AND xrcc.process_flag      = 'N'
						ORDER BY xrcc.country)
		LOOP
			   v_error_message := 'Duplicate records are available in uploaded file';
								 -- || rec_dup.country;

			  UPDATE xxha_reg_country_control_stg
			     SET process_flag  = 'D',
				     error_message = v_error_message
			   WHERE 1=1
				 AND country_code = rec_dup.country_code
				 AND country             = rec_dup.country
				 AND process_flag          = 'N'
				 AND batch_id              = g_batch_id;
		 END LOOP;
		 COMMIT;
	EXCEPTION
		WHEN OTHERS THEN
			--DBMS_OUTPUT.PUT_LINE( 'Error while updating the duplicate records - SQLERRM -' || SQLERRM);
      DBMS_OUTPUT.PUT_LINE( 'Error while updating the duplicate records - SQLERRM -' || SQLERRM);
			RAISE;
	END;

	BEGIN
		validate_data(g_batch_id);

		/*UPDATE xxha_reg_country_control_stg stg
		   SET country_control_id = ( SELECT MAX(COUNTRY_CONTROL_ID)+1
									  FROM XXHA_REG_COUNTRY_CONTROL)
		 WHERE process_flag = 'N'
		   AND batch_id     = g_batch_id
		   AND request_id   = p_request_id ;*/
	END;
	BEGIN
		SELECT *
		  BULK COLLECT
		  INTO v_rec_data
		  FROM  xxha_reg_country_control_stg
		 WHERE 1=1
		   AND process_flag = 'N'
      -- AND COUNTRY_CODE = 'ID'
		 --  AND insert_allowed IN ('Y','N')
		   AND batch_id       = g_batch_id;
	EXCEPTION
	WHEN OTHERS THEN
 DBMS_OUTPUT.put_line('Error while bulk collecting the records - SQLERRM  ');
		--DBMS_OUTPUT.PUT_LINE( 'Error while bulk collecting the records - SQLERRM -' || SQLERRM);
   -- DBMS_OUTPUT.put_line('Error while bulk collecting the records - SQLERRM -' || SQLERRM);
		RAISE;
	END;

	FOR indx IN v_rec_data.FIRST ..v_rec_data.LAST LOOP
	IF v_rec_data(indx).insert_allowed = 'Y'
  THEN
		BEGIN
		INSERT INTO xxha_reg_country_control (COUNTRY_CONTROL_ID,
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
											  ENABLED_FLAG ,
											  CREATION_DATE ,
											  CREATED_BY ,
											  LAST_UPDATE_DATE,
											  LAST_UPDATED_BY)
									VALUES (( SELECT MAX(COUNTRY_CONTROL_ID)+1 FROM XXHA_REG_COUNTRY_CONTROL),
											 v_rec_data(indx).COUNTRY_CODE,
                         INITCAP(v_rec_data(indx).COUNTRY),
											   v_rec_data(indx).STATE,
											  v_rec_data(indx).PROVINCE,
											  INITCAP(v_rec_data(indx).SITE_CONTROL_TYPE),
											  INITCAP(v_rec_data(indx).ITEM_CONTROL_TYPE) ,
											  INITCAP(v_rec_data(indx).BUSINESS_LICENSE_REQUIRED) ,
											  INITCAP(v_rec_data(indx).REGULATORY_LICENSE_REQUIRED),
											  INITCAP(v_rec_data(indx).APPROVED_PRODUCT_LIST),
											  INITCAP(v_rec_data(indx).REGULATORY_NOTIFICATION),
											  INITCAP(v_rec_data(indx).CUSTOMER_SERVICE_NOTIFICATION),
											  INITCAP(v_rec_data(indx).REGULATORY_REGISTRATION_REQ),
											  INITCAP(v_rec_data(indx).ENABLED_FLAG) ,
											  v_rec_data(indx).creation_date,--v_rec_data(indx).created_by,
											 p_user_id,
											 v_rec_data(indx).last_update_date,--v_rec_data(indx).last_updated_by,
											 p_user_id
											 );

					v_rowcnt:= v_rowcnt + SQL%ROWCOUNT;

		--DBMS_OUTPUT.PUT_LINE( 'Number of rows inserted in base table  - '|| v_rowcnt);

		EXCEPTION
		WHEN OTHERS THEN
			   v_error_message := 'Error inserting into base table  - '
								  || v_rec_data(indx).country
								  || ' - SQLERRM -'
								  || SQLERRM;
			UPDATE xxha_reg_country_control_stg xrcc
			SET
				process_flag = 'E',
				error_message = v_error_message
			WHERE 1=1
			  AND xrcc.country_code = v_rec_data(indx).country_code
			  AND xrcc.country             = v_rec_data(indx).country
			  AND xrcc.process_flag          = 'N'
			  AND xrcc.batch_id                    = g_batch_id;

				/*DBMS_OUTPUT.PUT_LINE( 'Error Updating error flag item - '
												|| v_rec_data(indx).country
												|| ' - SQLERRM -'
												|| SQLERRM);*/
			--	RAISE;
		END;

			BEGIN
				UPDATE xxha_reg_country_control_stg xrcc
				   SET process_flag = 'S'
				 WHERE 1=1
				   AND xrcc.country_code = v_rec_data(indx).country_code
				   AND xrcc.country     = v_rec_data(indx).country
				   AND xrcc.process_flag  = 'N'
				   AND batch_id            = g_batch_id;
			EXCEPTION
			WHEN OTHERS THEN
				DBMS_OUTPUT.PUT_LINE( 'Error Updating process flag - '
													|| v_rec_data(indx).country
													|| ' - SQLERRM -'
													|| SQLERRM);
				RAISE;
			END;

	ELSIF v_rec_data(indx).insert_allowed = 'N'
	  THEN
		BEGIN
		 UPDATE xxha_reg_country_control
			SET --enable_flag        = v_rec_data(indx).enable_flag,
				STATE			   = v_rec_data(indx).STATE,
				PROVINCE		   = v_rec_data(indx).PROVINCE,
				SITE_CONTROL_TYPE  = v_rec_data(indx).SITE_CONTROL_TYPE,
				ITEM_CONTROL_TYPE  = v_rec_data(indx).ITEM_CONTROL_TYPE ,
				BUSINESS_LICENSE_REQUIRED = v_rec_data(indx).BUSINESS_LICENSE_REQUIRED ,
				REGULATORY_LICENSE_REQUIRED	= v_rec_data(indx).REGULATORY_LICENSE_REQUIRED,
				APPROVED_PRODUCT_LIST =		  v_rec_data(indx).APPROVED_PRODUCT_LIST,
				REGULATORY_NOTIFICATION =	  v_rec_data(indx).REGULATORY_NOTIFICATION,
				CUSTOMER_SERVICE_NOTIFICATION  = v_rec_data(indx).CUSTOMER_SERVICE_NOTIFICATION,
				REGULATORY_REGISTRATION_REQ	   = v_rec_data(indx).REGULATORY_REGISTRATION_REQ,
				LAST_UPDATED_BY         = v_rec_data(indx).last_updated_by,
				LAST_UPDATE_DATE         = v_rec_data(indx).last_update_date
		  WHERE 1=1
			AND country              = v_rec_data(indx).country
			AND country_code  = v_rec_data(indx).country_code ;

		 v_cnt:= v_cnt + SQL%ROWCOUNT;

		EXCEPTION
		WHEN OTHERS THEN
			   v_error_message := 'Error updating  - '
								  || v_rec_data(indx).country
								  || ' - SQLERRM -'
								  || SQLERRM;
			UPDATE xxha_reg_country_control_stg xrcc
			   SET process_flag = 'E',
				   error_message = v_error_message
			 WHERE 1=1
			   AND xrcc.country_code = v_rec_data(indx).country_code
			   AND xrcc.country         = v_rec_data(indx).country
			   AND xrcc.process_flag      = 'N'
			   AND batch_id                = g_batch_id;

				DBMS_OUTPUT.PUT_LINE( 'Error Updating item - '
												|| v_rec_data(indx).country
												|| ' - SQLERRM -'
												|| SQLERRM);

				RAISE;
		END;
		   -- The following update will set item records with processed flag 'P' (Processed) in xxha_reg_country_control_stg table
		BEGIN
			UPDATE xxha_reg_country_control_stg xrcc
			   SET process_flag = 'S'
			 WHERE 1=1
			   AND xrcc.country_code   = v_rec_data(indx).country_code
			   AND xrcc.country               = v_rec_data(indx).country
			   AND xrcc.process_flag            = 'N'
			   AND batch_id                      = g_batch_id;
		EXCEPTION
		WHEN OTHERS THEN
				DBMS_OUTPUT.PUT_LINE( 'Error Updating item - '
												|| v_rec_data(indx).country
												|| ' - SQLERRM -'
												|| SQLERRM);
				RAISE;
		END;
	END IF;
	END LOOP;
	COMMIT;
begin
xxha_log_display(g_batch_id);
end;
 /*select count(*) into v_error_cnt from xxha_reg_country_control_stg stg
 WHERE process_flag = 'E';
 end;
   DBMS_OUTPUT.PUT_LINE( 'Number of rows inserted in base table  - '|| v_rowcnt);
   DBMS_OUTPUT.PUT_LINE( 'Number of rows updated in base table  - '|| v_cnt);
   DBMS_OUTPUT.PUT_LINE( 'Number of Recored Error out  - '|| v_error_cnt);*/
EXCEPTION
	WHEN OTHERS THEN
		DBMS_OUTPUT.PUT_LINE( 'Exception occured in file upload package XXHA_REG_COUNTRY_DATA_PKG' || TO_CHAR
		(SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));

		DBMS_OUTPUT.PUT_LINE( 'Exception - XXHA_REG_COUNTRY_DATA_PKG package End Time with error - '
										|| TO_CHAR(systimestamp, 'DD-MON-YYYY HH24:MI:SS')
										|| ' - SQLERRM -'
										|| SQLERRM);
        DBMS_OUTPUT.put_line('Exception - XXHA_REG_COUNTRY_DATA_PKG package End Time with error - ');

END main_proc;
PROCEDURE Inclusion_main_proc (
	p_user_id      IN    NUMBER,
	p_request_id   IN    NUMBER,
	p_file_name    IN    VARCHAR2,
	p_source       IN    VARCHAR2,
	p_batch_id     IN    NUMBER,
  p_country_code       IN    VARCHAR2--  PRADUMAN
) IS
	v_rec_data       g_tab_iteminc_data;
	v_cnt                NUMBER :=0;
    v_error_cnt          NUMBER :=0;
	v_request_id         NUMBER;
	v_resp_id            NUMBER;
	v_resp_appl_id       NUMBER;
	v_insert_allowed     VARCHAR2(1) := NULL;
	v_data_retain        NUMBER;
	v_item_id            NUMBER;
	v_rowcnt             NUMBER :=0;
	v_error_message      VARCHAR2(32000);
BEGIN
	g_batch_id := p_batch_id;
	DBMS_OUTPUT.PUT_LINE( 'Start of the Regulatory Item Inclusion Upload program');

	/*BEGIN
	  UPDATE xxha_item_registration_stg
		 SET batch_id           = g_batch_id,
			 request_id         = p_request_id,
			 file_name          = p_file_name,
			 created_by         = p_user_id,          
			 last_updated_by    = p_user_id
	  WHERE 1=1
		AND batch_source   = p_source
		AND process_flag   = 'N'
		AND batch_id IS NULL;

	COMMIT;
	EXCEPTION WHEN OTHERS THEN
	--	DBMS_OUTPUT.PUT_LINE( 'Error while updating batch id - SQLERRM -' || SQLERRM);
   DBMS_OUTPUT.PUT_LINE('Error while updating batch id - SQLERRM -' || SQLERRM);
		RAISE;
	END;  */ --PRADUMAN

BEGIN
	   FOR rec_dup IN (SELECT xrcc.*
						 FROM xxha_item_registration_stg xrcc
							  ,(SELECT item_number,country_code,item_reg_start_date, nvl(item_reg_end_date,'01-JAN-4977') ,COUNT(*)
								 FROM xxha_item_registration_stg
								WHERE 1=1
								  AND batch_id     = g_batch_id
								  AND process_flag = 'N'
								GROUP BY item_number,country_code,item_reg_start_date, nvl(item_reg_end_date,'01-JAN-4977')
							   HAVING COUNT(*) > 1 ) dup
						WHERE xrcc.country_code = dup.country_code
						  AND xrcc.item_number         = dup.item_number
						  AND xrcc.batch_id          = g_batch_id
						  AND xrcc.process_flag      = 'N'
						ORDER BY xrcc.item_number)
		LOOP
			   v_error_message := 'Duplicate records are available in uploaded file';
								 -- || rec_dup.country;

			  UPDATE xxha_item_registration_stg
			     SET process_flag  = 'D',
				     error_message = v_error_message
			   WHERE 1=1
				 AND country_code = rec_dup.country_code
				 AND item_number             = rec_dup.item_number
				 AND process_flag          = 'N'
				 AND batch_id              = g_batch_id;
		 END LOOP;
		 COMMIT;
	EXCEPTION
		WHEN OTHERS THEN
			--DBMS_OUTPUT.PUT_LINE( 'Error while updating the duplicate records - SQLERRM -' || SQLERRM);
      DBMS_OUTPUT.PUT_LINE( 'Error while updating the duplicate records - SQLERRM -' || SQLERRM);
			RAISE;
	END;

	BEGIN
		validate_Item_inclusion_data(g_batch_id
                                  , p_country_code);    --PRADUMAN

		/*UPDATE xxha_reg_country_control_stg stg
		   SET country_control_id = ( SELECT MAX(COUNTRY_CONTROL_ID)+1
									  FROM XXHA_REG_COUNTRY_CONTROL)
		 WHERE process_flag = 'N'
		   AND batch_id     = g_batch_id
		   AND request_id   = p_request_id ;*/
	END;
	BEGIN
		SELECT *
		  BULK COLLECT
		  INTO v_rec_data
		  FROM  xxha_item_registration_stg
		 WHERE 1=1
		   AND process_flag = 'V'
      -- AND COUNTRY_CODE = 'ID'
       AND COUNTRY_CODE =  p_country_code   --PRADUMAN
		   AND insert_allowed IN ('Y','N')
		   AND batch_id       = g_batch_id;
	EXCEPTION
	WHEN OTHERS THEN
 DBMS_OUTPUT.put_line('Error while bulk collecting the records - SQLERRM  ');
		--DBMS_OUTPUT.PUT_LINE( 'Error while bulk collecting the records - SQLERRM -' || SQLERRM);
   -- DBMS_OUTPUT.put_line('Error while bulk collecting the records - SQLERRM -' || SQLERRM);
		RAISE;
	END;

	FOR indx IN v_rec_data.FIRST ..v_rec_data.LAST LOOP
	IF v_rec_data(indx).insert_allowed = 'Y'  
  THEN
		BEGIN
		INSERT INTO xxha_item_registration (ITEM_REGISTRATION_ID,       
											ITEM_NUMBER    ,
											ITEM_DESCRIPTION  ,
											REGULATORY_AGENCY  ,
											REGISTRATION_NUM  ,
											ITEM_REG_START_DATE ,       
											ITEM_REG_END_DATE ,     
											COUNTRY_CONTROL_ID  ,       
											REGISTERED_LEGAL_ENTITY   ,
											MANUFACTURING_SITE   ,
											ITEM_NAME_LOCAL_LANGUAGE,
											PACKING_STD_EQUIP_MODEL ,
											CATEGORY_CODE ,
                      ACTIVE_FLAG,
											CREATION_DATE ,
											CREATED_BY ,
											LAST_UPDATE_DATE,
											LAST_UPDATED_BY)
									VALUES (XXHA_REG_COUNTRY_ITEM_ID_S.NEXTVAL,
											 v_rec_data(indx).ITEM_NUMBER,
											 v_rec_data(indx).ITEM_DESCRIPTION,
											 v_rec_data(indx).REGULATORY_AGENCY,
											 v_rec_data(indx).REGISTRATION_NUM ,
											 v_rec_data(indx).ITEM_REG_START_DATE,
											 v_rec_data(indx).ITEM_REG_END_DATE ,
											 v_rec_data(indx).COUNTRY_CONTROL_ID ,
											 v_rec_data(indx).REGISTERED_LEGAL_ENTITY,
											 v_rec_data(indx).MANUFACTURING_SITE,
											 v_rec_data(indx).ITEM_NAME_LOCAL_LANGUAGE,
											 v_rec_data(indx).PACKING_STD_EQUIP_MODEL,
											 v_rec_data(indx).CATEGORY_CODE,
                        v_rec_data(indx).ACTIVE_FLAG,
											 v_rec_data(indx).creation_date,--v_rec_data(indx).created_by,
											 p_user_id,
											 v_rec_data(indx).last_update_date,--v_rec_data(indx).last_updated_by,
											 p_user_id
											 );

					v_rowcnt:= v_rowcnt + SQL%ROWCOUNT;

		--DBMS_OUTPUT.PUT_LINE( 'Number of rows inserted in base table  - '|| v_rowcnt);

		EXCEPTION
		WHEN OTHERS THEN
			   v_error_message := 'Error inserting into base table  - '
								  || v_rec_data(indx).item_number
								  || ' - SQLERRM -'
								  || SQLERRM;
			UPDATE xxha_item_registration_stg xrcc
			SET
				process_flag = 'E',
				error_message = v_error_message
			WHERE 1=1
			  AND xrcc.country_code = v_rec_data(indx).country_code
			  AND xrcc.item_number           = v_rec_data(indx).item_number
			  AND xrcc.process_flag          = 'V'
			  AND xrcc.batch_id              = g_batch_id;

				/*DBMS_OUTPUT.PUT_LINE( 'Error Updating error flag item - '
												|| v_rec_data(indx).country
												|| ' - SQLERRM -'
												|| SQLERRM);*/
			--	RAISE;
		END;

			BEGIN
				UPDATE xxha_item_registration_stg xrcc
				   SET process_flag = 'S'
				 WHERE 1=1
				   AND xrcc.country_code = v_rec_data(indx).country_code
				   AND xrcc.item_number     = v_rec_data(indx).item_number
				   AND xrcc.process_flag  = 'V'
				   AND batch_id            = g_batch_id;
			EXCEPTION
			WHEN OTHERS THEN
				DBMS_OUTPUT.PUT_LINE( 'Error Updating process flag - '
													|| v_rec_data(indx).item_number
													|| ' - SQLERRM -'
													|| SQLERRM);
				RAISE;
			END;

	ELSIF v_rec_data(indx).insert_allowed = 'N'  --PRADUMAN
	  THEN
		BEGIN
		 UPDATE xxha_item_registration
			SET 
				REGULATORY_AGENCY  =        NVL(v_rec_data(indx).REGULATORY_AGENCY,REGULATORY_AGENCY),
				REGISTRATION_NUM =			NVL(v_rec_data(indx).REGISTRATION_NUM,REGISTRATION_NUM) ,
				ITEM_REG_START_DATE = 		NVL(v_rec_data(indx).ITEM_REG_START_DATE,ITEM_REG_START_DATE),
				ITEM_REG_END_DATE=	 		NVL(v_rec_data(indx).ITEM_REG_END_DATE,ITEM_REG_END_DATE) ,
				REGISTERED_LEGAL_ENTITY= 	NVL(v_rec_data(indx).REGISTERED_LEGAL_ENTITY,REGISTERED_LEGAL_ENTITY),
				MANUFACTURING_SITE=			NVL(v_rec_data(indx).MANUFACTURING_SITE,MANUFACTURING_SITE),
				ITEM_NAME_LOCAL_LANGUAGE= 	NVL(v_rec_data(indx).ITEM_NAME_LOCAL_LANGUAGE,ITEM_NAME_LOCAL_LANGUAGE),
				PACKING_STD_EQUIP_MODEL=	NVL(v_rec_data(indx).PACKING_STD_EQUIP_MODEL,PACKING_STD_EQUIP_MODEL),
				CATEGORY_CODE=		 		NVL(v_rec_data(indx).CATEGORY_CODE,CATEGORY_CODE),
				LAST_UPDATED_BY  = 			v_rec_data(indx).last_updated_by,
				LAST_UPDATE_DATE  = 		v_rec_data(indx).last_update_date
		  WHERE 1=1
			AND item_number   = v_rec_data(indx).item_number
			AND country_control_id  = v_rec_data(indx).country_control_id
      AND nvl(MANUFACTURING_SITE,1) = NVL(v_rec_data(indx).MANUFACTURING_SITE,nvl(MANUFACTURING_SITE,1));

		 v_cnt:= v_cnt + SQL%ROWCOUNT;

		EXCEPTION
		WHEN OTHERS THEN
			   v_error_message := 'Error updating  - '
								  || v_rec_data(indx).item_number
								  || ' - SQLERRM -'
								  || SQLERRM;
			UPDATE xxha_item_registration_stg xrcc
			   SET process_flag = 'E',
				   error_message = v_error_message
			 WHERE 1=1
			   AND xrcc.country_code = v_rec_data(indx).country_code
			   AND xrcc.item_number         = v_rec_data(indx).item_number
			   AND xrcc.process_flag      = 'V'
			   AND batch_id                = g_batch_id;
         COMMIT ; --PRADUMAN

				/*DBMS_OUTPUT.PUT_LINE( 'Error Updating item - '
												|| v_rec_data(indx).item_number
												|| ' - SQLERRM -'
												|| SQLERRM);

				RAISE;*/
		END;  --PRADUMAN
		   -- The following update will set item records with processed flag 'P' (Processed) in xxha_reg_country_control_stg table
		BEGIN
			UPDATE xxha_item_registration_stg xrcc
			   SET process_flag = 'S'
			 WHERE 1=1
			   AND xrcc.country_code   = v_rec_data(indx).country_code
			   AND xrcc.item_number    = v_rec_data(indx).item_number
			   AND xrcc.process_flag   = 'V'
			   AND batch_id            = g_batch_id;
         COMMIT; --PRADUMAN
		EXCEPTION
		WHEN OTHERS THEN
				DBMS_OUTPUT.PUT_LINE( 'Error Updating item - '
												|| v_rec_data(indx).item_number
												|| ' - SQLERRM -'
												|| SQLERRM);
				--RAISE;
		END;
	END IF;
  COMMIT;
	END LOOP;
  v_rec_data.delete;
	COMMIT;
begin
xxha_log_display_inclusion(g_batch_id);
end;
EXCEPTION
	WHEN OTHERS THEN
		DBMS_OUTPUT.PUT_LINE( 'Exception occured in file upload package XXHA_REG_COUNTRY_DATA_PKG' || TO_CHAR
		(SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));

		DBMS_OUTPUT.PUT_LINE( 'Exception - XXHA_REG_COUNTRY_DATA_PKG package End Time with error - '
										|| TO_CHAR(systimestamp, 'DD-MON-YYYY HH24:MI:SS')
										|| ' - SQLERRM -'
										|| SQLERRM);
        DBMS_OUTPUT.put_line('Exception - XXHA_REG_COUNTRY_DATA_PKG package End Time with error - ');

END Inclusion_main_proc;
    /*************************************************************************************
     Procedure to print/display into concurrent program output log file when there are 
     any duplicate item records uploaded into XXHA_REG_COUNTRY_CONTROL_STG table and items 
     failed/error out during update to SCIM table 
    *************************************************************************************/
    PROCEDURE xxha_log_display (
        p_batch_id IN varchar2
    ) IS

        v_processed_count     NUMBER := 0;
        v_error_count         NUMBER := 0;
        v_unvalidated_count   NUMBER := 0;
        v_total_records       NUMBER := 0;
        v_duplicate_count     NUMBER := 0;
        
   -- Below cursor will fetch all error records from staging table to display in log file.
        CURSOR c_error_records IS
        SELECT country_control_id item_no,
            Country,
            error_message
        FROM
            xxha_reg_country_control_stg
        WHERE
            process_flag = 'E'
            AND batch_id = p_batch_id 
        ORDER BY
            country_control_id;
            
        -- Below cursor will fetch all duplicate records from staging table to display in log file.
        CURSOR c_dup_records IS
        SELECT DISTINCT country_control_id  Item_no,
            country,
            error_message
        FROM
            xxha_reg_country_control_stg
        WHERE
            process_flag = 'D'
            AND batch_id = p_batch_id
        ORDER BY
            country_control_id;
        
    BEGIN
      
        SELECT
            COUNT(*)
        INTO v_total_records
        FROM
            xxha_reg_country_control_stg
        WHERE
            batch_id = p_batch_id; 

        SELECT
            COUNT(*)
        INTO v_processed_count
        FROM
            xxha_reg_country_control_stg
        WHERE
            process_flag = 'S'
            AND batch_id = p_batch_id;

        SELECT
            COUNT(*)
        INTO v_error_count
        FROM
            xxha_reg_country_control_stg
        WHERE
            process_flag = 'E'
            AND batch_id = p_batch_id; 
            
        SELECT
            COUNT(*)
        INTO v_duplicate_count
        FROM
            xxha_reg_country_control_stg
        WHERE
            process_flag = 'D'
            AND batch_id = p_batch_id; 

        SELECT
            COUNT(*)
        INTO v_unvalidated_count
        FROM
            xxha_reg_country_control_stg
        WHERE
            process_flag = 'N'
            AND batch_id = p_batch_id; 
        dbms_output.put_line(chr(30)); 
        dbms_output.put_line( 'Complete Stats Of REGULATORY File Upload Process');
        dbms_output.put_line( '-------------------------------------------------------------------------------'
        );
        dbms_output.put_line(' ');
        dbms_output.put_line('Number of records in stagging table are - ' || v_total_records);
        dbms_output.put_line(' ');
        dbms_output.put_line( 'Number of records got processed in to Base table are - ' || v_processed_count);
        dbms_output.put_line( ' ');
        dbms_output.put_line( 'Number of records got Error in to  Staging table are  - ' || v_error_count);
        dbms_output.put_line( ' ');
        dbms_output.put_line( 'Number of records got Skipped due to duplicate in Staging table are  - ' || v_duplicate_count);
        dbms_output.put_line( ' ');
        dbms_output.put_line( 'Number of records not validated in  staging table are - ' || v_unvalidated_count);
    
        dbms_output.put_line( chr(30));
        dbms_output.put_line( chr(30));
    
        dbms_output.put_line( 'Duplicate items skipped during upload process');
        dbms_output.put_line( '-----------------------------------------------------------------------------------'
        );       
       dbms_output.put_line( rpad('Item No', 30)||rpad('Country', 30)
                                        || rpad('Error Description', 50));

      
         dbms_output.put_line( rpad('------------', 30)||rpad('------------', 30)||rpad('-------------------', 50)
        );
        FOR rec_dup_records IN c_dup_records 
        LOOP 
                           dbms_output.put_line( rpad(rec_dup_records.item_no, 30)||rpad(rec_dup_records.country, 30)
                                        || rec_dup_records.error_message);
        END LOOP;
       dbms_output.put_line( chr(30));
       dbms_output.put_line( chr(30));
                  
        dbms_output.put_line( 'Record error out during upload process ');
        dbms_output.put_line( '-----------------------------------------------------------------------------------'
        );
               dbms_output.put_line( rpad('Item No', 30)|| rpad('Country', 30)
                                        || rpad('Error Description', 50));


        dbms_output.put_line( rpad('------------', 30) ||rpad('-------------------', 30)
                        ||rpad('-------------------', 50));
                        
        FOR rec_error_records IN c_error_records 
        LOOP
                          dbms_output.put_line( rpad(rec_error_records.item_no, 30)||rpad(rec_error_records.country, 30)
                                             || rec_error_records.error_message);
        END LOOP;
     EXCEPTION
        WHEN OTHERS THEN
            dbms_output.put_line( 'Exception occured while in  XXHA_REG_COUNTRY_DATA_PKG.xxha_log_display procedure '
                                            || sqlcode
                                            || '-'
                                            || sqlerrm);

            RAISE;
    END xxha_log_display;
 PROCEDURE XXHA_LOG_DISPLAY_INCLUSION (
        p_batch_id IN varchar2
    ) IS
        v_processed_count     NUMBER := 0;
        v_error_count         NUMBER := 0;
        v_unvalidated_count   NUMBER := 0;
        v_total_records       NUMBER := 0;
        v_duplicate_count     NUMBER := 0;
        
   -- Below cursor will fetch all error records from staging table to display in log file.
        CURSOR c_error_records IS
        SELECT row_number item_no,
            Country_code,
			item_number,
            error_message
        FROM
            xxha_item_registration_stg
        WHERE
            process_flag = 'E'
            AND batch_id = p_batch_id 
        ORDER BY
            row_number;
            
        -- Below cursor will fetch all duplicate records from staging table to display in log file.
        CURSOR c_dup_records IS
        SELECT DISTINCT
            row_number item_no,
            Country_code,
			item_number,
            error_message
        FROM
            xxha_item_registration_stg
        WHERE
            process_flag = 'D'
            AND batch_id = p_batch_id
        ORDER BY
            row_number;
        
    BEGIN
      
        SELECT
            COUNT(*)
        INTO v_total_records
        FROM
            xxha_item_registration_stg
        WHERE
            batch_id = p_batch_id; 

        SELECT
            COUNT(*)
        INTO v_processed_count
        FROM
            xxha_item_registration_stg
        WHERE
            process_flag = 'S'
            AND batch_id = p_batch_id;

        SELECT
            COUNT(*)
        INTO v_error_count
        FROM
            xxha_item_registration_stg
        WHERE
            process_flag = 'E'
            AND batch_id = p_batch_id; 
            
        SELECT
            COUNT(*)
        INTO v_duplicate_count
        FROM
            xxha_item_registration_stg
        WHERE
            process_flag = 'D'
            AND batch_id = p_batch_id; 

        SELECT
            COUNT(*)
        INTO v_unvalidated_count
        FROM
            xxha_item_registration_stg
        WHERE
            process_flag = 'N'
            AND batch_id = p_batch_id; 
        dbms_output.put_line(chr(30)); 
        dbms_output.put_line( 'Complete Stats Of REGULATORY File Upload Process');
        dbms_output.put_line( '-------------------------------------------------------------------------------'
        );
        dbms_output.put_line(' ');
        dbms_output.put_line('Number of records in stagging table are - ' || v_total_records);
        dbms_output.put_line(' ');
        dbms_output.put_line( 'Number of records got processed in to Base table are - ' || v_processed_count);
        dbms_output.put_line( ' ');
        dbms_output.put_line( 'Number of records got Error in to  Staging table are  - ' || v_error_count);
        dbms_output.put_line( ' ');
        dbms_output.put_line( 'Number of records got Skipped due to duplicate in Staging table are  - ' || v_duplicate_count);
        dbms_output.put_line( ' ');
        dbms_output.put_line( 'Number of records not validated in  staging table are - ' || v_unvalidated_count);
    
        dbms_output.put_line( chr(30));
        dbms_output.put_line( chr(30));
    
        dbms_output.put_line( 'Duplicate items skipped during upload process');
        dbms_output.put_line( '-----------------------------------------------------------------------------------'
        );       
        dbms_output.put_line( rpad('Row No', 30)|| rpad('Country', 30)|| rpad('Item', 30)
                                        || rpad('Error Description', 50));

      
         dbms_output.put_line( rpad('------------', 30)||rpad('-------------------', 30)||rpad('-------------------', 30)||rpad('-------------------', 50)
        );
        FOR rec_dup_records IN c_dup_records 
        LOOP 
                           dbms_output.put_line( rpad(rec_dup_records.item_no, 30)||rpad(rec_dup_records.country_code, 30)
                                       ||rpad(rec_dup_records.item_number, 30) ||rec_dup_records.error_message);
        END LOOP;
       dbms_output.put_line( chr(30));
       dbms_output.put_line( chr(30));
                  
        dbms_output.put_line( 'Record error out during upload process ');
        dbms_output.put_line( '-----------------------------------------------------------------------------------'
        );
          /*     dbms_output.put_line( rpad('Row No', 30)|| rpad('Country', 30)|| rpad('Item', 30)
                                        || rpad('Error Description', 50));


        dbms_output.put_line( rpad('------------', 30) ||rpad('-------------------', 30)||rpad('-------------------', 30)
                        ||rpad('-------------------', 50));
                        
        FOR rec_error_records IN c_error_records 
        LOOP
                          dbms_output.put_line( rpad(rec_error_records.item_no, 30)||rpad(rec_error_records.country_code, 30)
                                              ||rpad(rec_error_records.item_number, 30) ||rec_error_records.error_message);
        END LOOP;*/
     EXCEPTION
        WHEN OTHERS THEN
            dbms_output.put_line( 'Exception occured while in  XXHA_REG_COUNTRY_DATA_PKG.xxha_log_display procedure '
                                            || sqlcode
                                            || '-'
                                            || sqlerrm);

            RAISE;
END xxha_log_display_inclusion;
PROCEDURE inclusion_main_proc_country (
	p_user_id      IN    NUMBER,
	p_request_id   IN    NUMBER,
	p_file_name    IN    VARCHAR2,
	p_source       IN    VARCHAR2,
	p_batch_id     IN    NUMBER
) IS
	v_error_message      VARCHAR2(32000);
BEGIN
--	g_batch_id := p_batch_id;
	DBMS_OUTPUT.PUT_LINE( 'Start of the Regulatory Header Upload program');

BEGIN
	  UPDATE xxha_item_registration_stg
		 SET batch_id           = p_batch_id,
			 request_id         = p_request_id,
			 file_name          = p_file_name,
			 created_by         = p_user_id,          
			 last_updated_by    = p_user_id
	  WHERE 1=1
		AND batch_source   = p_source
		AND process_flag   = 'N'
		AND batch_id IS NULL;

	COMMIT;
	EXCEPTION WHEN OTHERS THEN
	--	DBMS_OUTPUT.PUT_LINE( 'Error while updating batch id - SQLERRM -' || SQLERRM);
   DBMS_OUTPUT.PUT_LINE('Error while updating batch id - SQLERRM -' || SQLERRM);
		RAISE;
	END;


	BEGIN
	   FOR rec_batch_org IN (SELECT DISTINCT xrcc.country_control_id,xirc.country_code
						 FROM xxha_item_registration_stg xirc,
								xxha_reg_country_control  xrcc
						WHERE xrcc.country_code = xirc.country_code
						  AND xirc.batch_id          = p_batch_id
						  AND xirc.process_flag      = 'N'
						ORDER BY xrcc.country_control_id)
		LOOP
         BEGIN
         DBMS_OUTPUT.PUT_LINE( 'start' || to_char(sysdate,'DD/MON/YYYY HH24:MI:SS'));
		   Inclusion_main_proc(p_user_id ,p_request_id,'XXHA_REG_ITEMINC_FLAT_FILE','REG',p_batch_id,rec_batch_org.country_code); 
			END;
       COMMIT;
        DBMS_OUTPUT.PUT_LINE( 'End' || to_char(sysdate,'DD/MON/YYYY HH24:MI:SS'));
		 END LOOP;
		-- COMMIT;
	EXCEPTION
		WHEN OTHERS THEN
			--DBMS_OUTPUT.PUT_LINE( 'Error while updating the duplicate records - SQLERRM -' || SQLERRM);
      DBMS_OUTPUT.PUT_LINE( 'Error while process records - SQLERRM -' || SQLERRM);
	END;
					--v_rowcnt:= v_rowcnt + SQL%ROWCOUNT;   

END inclusion_main_proc_country;
END XXHA_REG_COUNTRY_DATA_PKG;