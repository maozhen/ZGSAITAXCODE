FUNCTION EXEC_RFTAXIMP.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     VALUE(CTU) LIKE  APQI-PUTACTIVE DEFAULT 'X'
*"     VALUE(MODE) LIKE  APQI-PUTACTIVE DEFAULT 'N'
*"     VALUE(UPDATE) LIKE  APQI-PUTACTIVE DEFAULT 'L'
*"     VALUE(GROUP) LIKE  APQI-GROUPID OPTIONAL
*"     VALUE(USER) LIKE  APQI-USERID OPTIONAL
*"     VALUE(KEEP) LIKE  APQI-QERASE OPTIONAL
*"     VALUE(HOLDDATE) LIKE  APQI-STARTDATE OPTIONAL
*"     VALUE(NODATA) LIKE  APQI-PUTACTIVE DEFAULT '/'
*"     VALUE(I_TRKORR) LIKE  T007V-TRKORR
*"     VALUE(I_ALAND) LIKE  T007V-ALAND
*"  EXPORTING
*"     VALUE(SUBRC) LIKE  SYST-SUBRC
*"  TABLES
*"      MESSTAB STRUCTURE  BDCMSGCOLL OPTIONAL
*"----------------------------------------------------------------------

subrc = 0.

perform bdc_nodata      using NODATA.

perform open_group      using GROUP USER KEEP HOLDDATE CTU.

perform bdc_dynpro      using 'SAPLWBABAP' '0100'.
perform bdc_field       using 'BDC_CURSOR'
                              'RS38M-PROGRAMM'.
perform bdc_field       using 'BDC_OKCODE'
                              '=STRT'.
perform bdc_field       using 'RS38M-PROGRAMM'
                              'RFTAXIMP'.
perform bdc_field       using 'RS38M-FUNC_EDIT'
                              'X'.
perform bdc_dynpro      using 'RFTAXIMP' '1000'.
perform bdc_field       using 'BDC_CURSOR'
                              'ALAND'.
perform bdc_field       using 'BDC_OKCODE'
                              '=ONLI'.
perform bdc_field       using 'TRKORR'
                              I_TRKORR.
perform bdc_field       using 'ALAND'
                              I_ALAND.
perform bdc_field       using 'USE_DTAM'
                              'X'.
perform bdc_dynpro      using 'SAPMSSY0' '0120'.
perform bdc_field       using 'BDC_CURSOR'
                              '01/02'.
perform bdc_field       using 'BDC_OKCODE'
                              '=BACK'.
perform bdc_dynpro      using 'SAPLSBAL_DISPLAY' '0100'.
perform bdc_field       using 'BDC_OKCODE'
                              '=&F03'.
perform bdc_dynpro      using 'RFTAXIMP' '1000'.
perform bdc_field       using 'BDC_OKCODE'
                              '/EE'.
perform bdc_field       using 'BDC_CURSOR'
                              'TRKORR'.
perform bdc_dynpro      using 'SAPLWBABAP' '0100'.
perform bdc_field       using 'BDC_CURSOR'
                              'RS38M-PROGRAMM'.
perform bdc_field       using 'BDC_OKCODE'
                              '=BACK'.
perform bdc_field       using 'RS38M-PROGRAMM'
                              'RFTAXIMP'.
perform bdc_field       using 'RS38M-FUNC_EDIT'
                              'X'.
perform bdc_transaction tables messtab
using                         'SE38'
                              CTU
                              MODE
                              UPDATE.
if sy-subrc <> 0.
  subrc = sy-subrc.
  exit.
endif.

perform close_group using     CTU.





ENDFUNCTION.
INCLUDE BDCRECXY .
