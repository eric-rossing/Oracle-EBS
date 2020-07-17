create or replace PROCEDURE XXHA_REG_BACKOUT_DATA ( 
        ERRBUFF  OUT VARCHAR2,
        RETCODE  OUT VARCHAR2,
        P_DELETION_TYPE IN VARCHAR2,
        P_COUNTRY_CODE IN NUMBER
    ) IS
/*==========================================================================|
|			 		     												                                      |
|  * Developer      : Praduman Singh                                         |
|  * Client/Project : HEMONETICS                                            |
|  * Date           : 14-JUL-2020                                           |
|  * Description    : This package contains the logic for Delete data from  | 
|                     Regulatory Header And Lines custom tables             |
|  * Issue          :                                                       |
|  * Version Control:                                                       |
|  * Author        Version             Date               Change            |
|   * -------       -------            --------          -------            |
|   * Praduman        0.0              14-JUL-2020         Initail Veriosn  |
|==========================================================================|*/
    BEGIN
    IF P_DELETION_TYPE = 'COUNTRY_HEADER'
     Then
     BEGIN
        DELETE FROM XXHA_REG_COUNTRY_CONTROL
        WHERE COUNTRY_CONTROL_ID = P_COUNTRY_CODE;
        EXCEPTION
            WHEN OTHERS THEN
            dbms_output.put_line( 'Exception occured while deleting the data from XXHA_REG_COUNTRY_CONTROL table '
                                            || sqlcode
                                            || '-'
                                            || sqlerrm);
     COMMIT;
     END;
     END IF;
    IF P_DELETION_TYPE = 'ITEM_INCLUSION' THEN
       BEGIN
        DELETE FROM XXHA_ITEM_REGISTRATION
        WHERE
            COUNTRY_CONTROL_ID  = P_COUNTRY_CODE;
       EXCEPTION
        WHEN OTHERS THEN
            dbms_output.put_line( 'Exception occured while deleting the data from "XXHA_ITEM_REGISTRATION" table '
                                            || sqlcode
                                            || '-'
                                            || sqlerrm);
     COMMIT;
     END;
     END IF;
    IF P_DELETION_TYPE = 'ITEM_EXCLUSION'
     Then
        BEGIN
        DELETE FROM XXHA_ITEM_REGISTRATION
        WHERE
            COUNTRY_CONTROL_ID =  P_COUNTRY_CODE;
          EXCEPTION
        WHEN OTHERS THEN
            dbms_output.put_line( 'Exception occured while deleting the data from "XXHA_ITEM_REGISTRATION" table '
                                            || sqlcode
                                            || '-'
                                            || sqlerrm);
     COMMIT;
     END;
     END IF;
    IF P_DELETION_TYPE = 'REG_CUSTOMER'
     Then
     BEGIN
        DELETE FROM XXHA_CUSTOMER_REG_CONTROL
        WHERE
            COUNTRY_CONTROL_ID =  P_COUNTRY_CODE;
       EXCEPTION
        WHEN OTHERS THEN
            dbms_output.put_line( 'Exception occured while deleting the data from "Xxha_Customer_Reg_Control" table '
                                            || sqlcode
                                            || '-'
                                            || sqlerrm);
     COMMIT;
     END;
     END IF;
    IF P_DELETION_TYPE = 'APP_CUSTOMER'
     Then
       BEGIN
        DELETE FROM XXHA_CUSTOMER_APPRV_PROD_LIST
        WHERE
            customer_reg_control_id = (SELECT B.customer_reg_control_id FROM XXHA_REG_COUNTRY_CONTROL A,
                                  XXHA_CUSTOMER_REG_CONTROL B
            WHERE A.COUNTRY_CONTROL_ID = P_COUNTRY_CODE
            AND A.COUNTRY_CONTROL_ID = B.COUNTRY_CONTROL_ID);
       EXCEPTION
        WHEN OTHERS THEN
            dbms_output.put_line( 'Exception occured while deleting the data from "XXHA_CUSTOMER_APPRV_PROD_LIST" table '
                                            || sqlcode
                                            || '-'
                                            || sqlerrm);
     COMMIT;
     END;
     END IF;
    EXCEPTION
        WHEN OTHERS THEN
            dbms_output.put_line( 'Exception occured while deleting the data from base table '
                                            || sqlcode
                                            || '-'
                                            || sqlerrm);

            RAISE;
    END XXHA_REG_BACKOUT_DATA ;