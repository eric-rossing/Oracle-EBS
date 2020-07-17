create or replace PACKAGE      xxha_reg_Notify
AS
   PROCEDURE xxha_reg_hold_notify (p_country_control_id   IN NUMBER,
                                   P_header_id               NUMBER);

   PROCEDURE xxha_reg_Release_notify (p_country_control_id   IN NUMBER,
                                      P_header_id               NUMBER);

   PROCEDURE XXHA_REG_NOTIFY_MAIN (errbuf                    OUT VARCHAR2,
                                   retcode                   OUT NUMBER);
                                 --  P_COUNTRY_CONTROL_ID   IN     NUMBER); Commented  by praduman for regulatory Project
END;