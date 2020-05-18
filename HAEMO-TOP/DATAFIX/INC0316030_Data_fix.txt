Step:1 --> Please run the below script to take the backup of a record into custom table.
----------------------------------------------------------------------------------------
create table XXHA_MMT_TEMP_TBL_INC0316030
as(SELECT *
FROM apps.mtl_material_transactions_temp
WHERE TRANSACTION_SOURCE_ID=
  (SELECT WIP_ENTITY_ID
  FROM APPS.WIP_DISCRETE_JOBS_V
  WHERE WIP_ENTITY_NAME='1060451'
  ));



Step:2 --> please run the below script to delete the record which has pending transaction.
------------------------------------------------------------------------------------------

delete from apps.mtl_material_transactions_temp
WHERE TRANSACTION_SOURCE_ID=
  (SELECT WIP_ENTITY_ID
  FROM APPS.WIP_DISCRETE_JOBS_V
  WHERE WIP_ENTITY_NAME='1060451'
  );

commit;

Testing steps:

after applied the script
add MFG Cost management responsibility
Run the close descrete jobs(SRS) with the parameter as job order number
after completed the program
goto -->view discrete jobs and serch with job number and you can see the status of job whether failed close or closed.
if it is failed close
try to run the job from close discrete jobs form.
then check it will be closed status.

if still not closed then wait for some time(the background process might be running)