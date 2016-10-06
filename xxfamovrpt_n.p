/*------------------------------------------------------------------------

  File:         xxfamovrpt.p

  Description:  Asset Movement Report
                Assets at Cost and Accumulated Depreciation
 
  History:
  
  Version Date     Author   Description
  ------- -------- -------- ---------------------------------------------
     2.00 07Sep16  Terry    Refactored original
          
------------------------------------------------------------------------*/
{mfdtitle.i}
{xxfa-func.i}

def new shared var entity      like fa_entity   label "Entity".
def new shared var entity1     like fa_entity   label "To".
def new shared var asset       like fab_fa_id   label "Asset".
def new shared var asset1      like fab_fa_id   label "To".
def new shared var cls         like fa_facls_id label "Class".
def new shared var cls1        like fa_facls_id label "To".
def new shared var assacc      like faba_acct   label "Asset Account".
def new shared var assacc1     like faba_acct   label "To".
def new shared var depacc      like ast_ac_acct label "Accum Depn Account".
def new shared var depacc1     like ast_ac_acct label "To".
def new shared var method      like fab_famt_id label "Method".
def new shared var method1     like fab_famt_id label "To".
def new shared var pass_domain like fa_domain.
def new shared var pass_book   like fabk_id.
def new shared var start_per   like fabd_yrper.
def new shared var end_per     like fabd_yrper.

def new shared temp-table t_famov
    field famov_domain             like fa_domain
    field famov_entity             like fa_entity
    field famov_fabk_id            like fabk_id
    field famov_fa_id              like fa_id
    field famov_fa_desc            like fa_desc1
    field famov_startdt            like fa_startdt
    field famov_disp_dt            like fa_disp_dt
    field famov_chr01              like fa__chr01
    field famov_chr02              like fa__chr02
    field famov_chr03              like fa__chr03
    field famov_chr04              like fa__chr04
    field famov_startyr            as char
    field famov_loadyr             as char
    field famov_transper           as char
    field famov_tr_entity_fr       like fa_entity
    field famov_tr_entity_to       like fa_entity
    field famov_dateloaded         like fa__dte01
    field famov_dep_method         like fab_famt_id
    field famov_dep_type           like famt_type
    field famov_dep_life           like fab_life
    field famov_facls_id           like facls_id
    field famov_facls_desc         like facls_desc
    field famov_ast_acct           like faba_acct
    field famov_ast_acct_desc      like ac_desc
    field famov_ast_sub            like faba_sub
    field famov_dep_acct           like faba_acct
    field famov_dep_acct_desc      like ac_desc
    field famov_acc_dep_sub        like faba_sub
    field famov_per_dep_acct       like faba_acct
    field famov_per_dep_sub        like faba_sub
    field famov_per_dep_cc         like faba_cc
    field famov_op_wdv             like fa_puramt
    field famov_cl_wdv             like fa_puramt
    field famov_op_bkcost          like fab_amt
    field famov_additions          like fa_puramt
    field famov_additions_u        like fa_puramt
    field famov_additions_o        like fa_puramt
    field famov_disposals          like fa_puramt
    field famov_cl_bkcost          like fab_amt
    field famov_op_accum_depn      like fa_puramt
    field famov_start_dep          like fa_puramt
    field famov_start_dep_3        like fa_puramt
    field famov_start_dep_1_5      like fa_puramt
    field famov_adds_dep           like fa_puramt
    field famov_disp_dep           like fa_puramt
    field famov_cl_accum_depn      like fa_puramt
    field famov_costAmt            like fabd_peramt
    field famov_proc_on_disp       like fa_dispamt
    field famov_in_vAccumDepBk     like fabd_accamt
    field famov_in_costAmt         like fabd_peramt
    field famov_out_vAccumDepBk    like fabd_accamt
    field famov_out_costAmt        like fabd_peramt
    field famov_vAccumDepBk        like fabd_accamt
    field famov_variance           like fabd_accamt
    field famov_report             as log
    field famov_message            as char
    index f_idx1 is primary
      famov_domain 
      famov_fabk_id 
      famov_entity 
      famov_chr04 
      famov_ast_sub 
      famov_fa_id 
    .

def var cyc_book              as char          no-undo init "BOOK,TAX,KIRN,TAX1".
def var vSubCode              as char          no-undo.
def var book                  like fabk_id     no-undo.
def var v_report              as char          no-undo 
  view-as radio-set vertical
    radio-buttons "Asset Cost Report Summary"                , "cost",
                  "Asset Accm Depn Report Summary"           , "acc dep",
                  "Asset Cost And Accum Depn Report Detail"  , "detail"
  label "Report Type".
def var file                  as char         no-undo format "x(50)" label "Output File". 
def var i                     as int          no-undo.

def stream outfile.

assign
  book    = getDefaultBook(global_domain)
  entity  = getDefaultEntity(global_domain, global_userid)
  entity1 = entity
  .

mainloop: 
repeat on endkey undo, return:

  empty temp-table t_famov.
  update
    start_per colon 20  end_per  label "To" colon 45
    entity    colon 20  entity1  colon 45
    book      colon 20
    asset     colon 20  asset1   colon 45
    cls       colon 20  cls1     colon 45
    assacc    colon 20  assacc1  colon 45
    depacc    colon 20  depacc1  colon 45
    method    colon 20  method1  colon 45
    skip(1)
    v_report  colon 20
    skip(1)
    with frame a side-labels.
    
  update v_report help "Choose a report to process." colon 20 skip with frame a.
    
  if  v_report = "detail" 
    then message "The report is too large and will be sent to a file.".
    
  vSubCode = "FAS_FAM_Report".
  {gprun.i ""xxstdtabgt.p"" "(""OUTPUT"", vSubCode, output file)"}
  
  file = if  file = "" 
         then "/tmp/" + vSubCode + "_" + trim(global_domain) + ".csv"
         else file + vSubCode + "_" + trim(global_domain) + ".csv" 
         .

  do transaction:
    update 
      file  label "Output File" 
      help "Extension defaults to csv" 
      colon 20 
      skip(1) with frame a.
    if  file = "" and v_report = "detail" then
    do: 
      {mfmsg.i 40 3}
      undo, retry.
    end.
  end. /* do transaction */
    
  if  file <> "" then
    output stream outfile to value(file + ".csv").
    
  assign
    entity1 = hi_char when entity1 = ""
    asset1  = hi_char when asset1 = ""
    cls1    = hi_char when cls1 = ""
    assacc1 = hi_char when assacc1 = ""
    depacc1 = hi_char when depacc1 = ""
    method1 = hi_char when method1 = ""
  .
    
  bcdparm = "".
    
  {mfquoter.i start_per}
  {mfquoter.i end_per}
  {mfquoter.i entity}
  {mfquoter.i entity1}
  {mfquoter.i book}
  {mfquoter.i asset}
  {mfquoter.i asset1}
  {mfquoter.i cls}
  {mfquoter.i cls1}
  {mfquoter.i assacc}
  {mfquoter.i assacc1}
  {mfquoter.i depacc}
  {mfquoter.i depacc1}
  {mfquoter.i method}
  {mfquoter.i method1}
  {mfquoter.i file}
  {mfquoter.i v_report}
  
  {mfselbpr.i "printer" 132}
  {mfphead.i}
  
  pass_domain = global_domain.

  do i = 1 to num-entries(cyc_book):
    if  book <> "" and book <> entry(i,cyc_book) then next.
    pass_book = entry(i,cyc_book).
    {gprun.i ""xxfamovprc_n.p""}
  end.

  if v_report = "cost" then
    run AssetCostReportSummary.
  else if v_report = "acc dep" then
    run AssetAccmDepnReportSummary.
  else 
    run AssetCostAndAccumDepnReportDetail.
    
  put stream outfile unformatted skip(2)
    "====================================================================" skip
    "====================================================================" skip
    "Period:,From:," start_per ",To:," end_per      skip
    "Entity:,From:," entity ",To:," entity1         skip
    "Book:,From:," book ",To:," book                skip
    "Asset:,From:," asset ",To:," asset1            skip
    "Class:,From:," cls ",To:," cls1                skip
    "Asset Account:,From:," assacc ",To:," assacc1  skip
    "Accum Depn Account:,From:," depacc ",To:," depacc1 skip
    "Forecast Method:,From:," method ",To:," method1 skip(2)
    .
  
  output stream outfile close.

  {mfrtrail.i}
    
end.

PROCEDURE AssetCostReportSummary:

  display "*** ASSET COST REPORT SUMMARY ***" skip(1)  with centered.

  put
/*           1         2         3         4         5         6         7         8         9         0         1         2         3         4        5          6         7 */
/*  12345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890 */
    "                                                                   Opening Balance                                    Closing Balance " at 1 skip
    "Entity Book Class Class Description    Asset Acct Acct Description Assets at Cost   Additions        Disposals        Assets at Cost  " at 1 skip 
    "------ ---- ----- -------------------- ---------- ---------------- ---------------- ---------------- ---------------- ----------------" at 1 skip
    .
    
  if  file <> "" then 
    put stream outfile 
      "*** ASSET COST REPORT SUMMARY ***" skip(1)
      "Entity,Book,Class,Class Description,Asset Acct,Acct Description,Opening Balance Assets at Cost,Additions,Disposals,Closing Balance Assets at Cost" skip
      "------,----,-----,-----------------,----------,----------------,---------------,---------,---------,---------------" skip
      .

  for each t_famov no-lock 
    break by famov_fabk_id by famov_ast_acct:
    
    accumulate
      famov_op_bkcost (total by famov_ast_acct)
      famov_additions (total by famov_ast_acct)
      famov_disposals (total by famov_ast_acct)
      famov_cl_bkcost (total by famov_ast_acct)
      .
        
    if last-of(famov_ast_acct) then
    do:
      put
        famov_entity 
        famov_fabk_id                                   at 8
        famov_facls_id                                  at 13 format "x(4)"
        famov_facls_desc                                at 19 format "x(20)"
        famov_ast_acct                                  at 40
        famov_ast_acct_desc                             at 51 format "x(16)" 
        (accum total by famov_ast_acct famov_op_bkcost) at 68 format "999999999999.99"
        (accum total by famov_ast_acct famov_additions) at 85 format "999999999999.99"
        (accum total by famov_ast_acct famov_disposals) at 102 format "999999999999.99"
        (accum total by famov_ast_acct famov_cl_bkcost) at 119 format "999999999999.99"
        skip
        .
            
      if file <> "" then 
        put stream outfile unformatted
          famov_entity        ","                                /* Entity */                        
          famov_fabk_id       ","                                /* Book */                          
          famov_facls_id      ","                                /* Class */                         
          famov_facls_desc    ","                                /* Class Description */             
          famov_ast_acct      ","                                /* Asset Acct */                    
          famov_ast_acct_desc ","                                /* Acct Description */              
          (accum total by famov_ast_acct famov_op_bkcost) ","    /* Opening Balance Assets at Cost */
          (accum total by famov_ast_acct famov_additions) ","    /* Additions */                     
          (accum total by famov_ast_acct famov_disposals) ","    /* Disposals */                     
          (accum total by famov_ast_acct famov_cl_bkcost) ","    /* Closing Balance Assets at Cost */
          skip
          .
    end. /* if last-of(famov_ast_acct) */
        
    if last(famov_ast_acct) then
    do:
      put 
        "================" at 68
        "================" at 85
        "================" at 102
        "================" at 119
        "TOTALS"           at 60
        (accum total famov_op_bkcost)  at 68 format "999999999999.99"
        (accum total famov_additions)  at 85 format "999999999999.99"
        (accum total famov_disposals)  at 102 format "999999999999.99"
        (accum total famov_cl_bkcost)  at 119 format "999999999999.99"
        .
    
      if  file <> "" then 
        put stream outfile unformatted
          ",,,,,,================,================,================,================," skip
          ",,,,,TOTALS," 
          (accum total famov_op_bkcost) "," 
          (accum total famov_additions) "," 
          (accum total famov_disposals) "," 
          (accum total famov_cl_bkcost)
          .
    end.

  end. /* for each t_famov */ 
        
     
END PROCEDURE.

PROCEDURE AssetAccmDepnReportSummary:
  
  display "*** ASSET ACCUMULATED DEPRECIATION REPORT SUMMARY ***" skip(1)  with centered.
    
  put
/*           1         2         3         4         5         6         7         8         9         0         1         2         3         4        5          6         7 */
/*  12345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890 */
   "                                                                      Opening Balance  Depreciation On  Depreciation On     Depreciation  Closing Balance" at 1 skip
   "Entity Book Class Class Description    Expense Acct Acct Description       Accum Depn  Assets at Start        Additions     On Disposals       Accum Depn" at 1 skip
   "------ ---- ----- -------------------- ------------ ---------------- ---------------- ---------------- ---------------- ---------------- ----------------" at 1 skip
   .
           
  if file <> "" then 
    put stream outfile
      "*** ASSET ACCUMULATED DEPRECIATION REPORT SUMMARY ***" skip
      "Entity,Book,Class,Class Description,Expense Acct,Stat Class,Stat PFO Class,Tax Class,Acct Description,Opening Balance Accum Depn,Depn On Assets at Start, Depn On Additions,Depn On Disposals, Closing Balance Accum Depn" skip
      "------,----,-----,--------------------,------------,----------,--------------,---------,----------------,----------------,----------------,----------------,----------------,----------------" skip
      .
        
  for each t_famov no-lock 
    break by famov_fabk_id by famov_dep_acct:
    
    accumulate
      famov_op_accum_depn (total by famov_dep_acct)
      famov_start_dep     (total by famov_dep_acct)
      famov_adds_dep      (total by famov_dep_acct)
      famov_disp_dep      (total by famov_dep_acct)
      famov_cl_accum_depn (total by famov_dep_acct)
      .

    if  last-of(famov_dep_acct) then
    do:
      put 
        famov_entity
        famov_fabk_id                                       at 8
        famov_facls_id                                      at 13 format "x(4)"  
        famov_facls_desc                                    at 19 format "x(20)" 
        famov_dep_acct                                      at 40
        famov_dep_acct_desc                                 at 53 format "x(16)" 
        (accum total by famov_dep_acct famov_op_accum_depn) at 70 format "999999999999.99"
        (accum total by famov_dep_acct famov_start_dep)     at 87 format "999999999999.99"
        (accum total by famov_dep_acct famov_adds_dep)      at 104 format "999999999999.99"
        (accum total by famov_dep_acct famov_disp_dep)      at 121 format "999999999999.99"
        (accum total by famov_dep_acct famov_cl_accum_depn) at 138 format "999999999999.99"
        skip
        .
    
      if file <> "" then 
        put stream outfile unformatted
          famov_entity        ","
          famov_fabk_id       ","
          famov_facls_id      ","
          famov_facls_desc    ","
          famov_chr01         "," 
          famov_chr02         "," 
          famov_chr03         "," 
          famov_dep_acct      ","
          famov_dep_acct_desc ","
          (accum total by famov_dep_acct famov_op_accum_depn) ","
          (accum total by famov_dep_acct famov_start_dep)     ","
          (accum total by famov_dep_acct famov_adds_dep)      ","
          (accum total by famov_dep_acct famov_disp_dep)      ","
          (accum total by famov_dep_acct famov_cl_accum_depn)
          skip
          .
    end. /* if last-of(famov_ast_acct) */
           
 
 
 
    if  last(famov_dep_acct) then
    do:
      put 
        "================"  at 70
        "================"  at 87
        "================"  at 104
        "================"  at 121
        "================"  at 138
        "TOTALS"            at 62
        (accum total famov_op_accum_depn) at 70 format "999999999999.99"
        (accum total famov_start_dep)     at 87 format "999999999999.99"
        (accum total famov_adds_dep)      at 104 format "999999999999.99"
        (accum total famov_disp_dep)      at 121 format "999999999999.99"
        (accum total famov_cl_accum_depn) at 138 format "999999999999.99"
        .
      
      if  file <> "" then 
        put stream outfile unformatted
          ",,,,,,================,================,================,================,================," skip
          ",,,,,TOTALS,"           
          (accum total famov_op_accum_depn) ","
          (accum total famov_start_dep)     ","
          (accum total famov_adds_dep)      ","
          (accum total famov_disp_dep)      ","
          (accum total famov_cl_accum_depn)
          .
    end.
      
  end. /* for each t_famov */
        
END PROCEDURE.

PROCEDURE AssetCostAndAccumDepnReportDetail:
    
  put stream outfile unformatted
    "*** ASSET COST AND ACCUMULATED DEPRECIATION REPORT DETAIL ***" skip
    "Entity,Book,Asset,Asset Description,Service Book Date,"
    "Service Period,Date Loaded,Loaded Period,Transfer Period,Entity From,Entity To,"
    "Disposal Date,Class,Class Desc,Stat Class,"
    "Tax Class,Asset Acct,Asset Acct Desc,Asset Sub-Acct,"
    "Accum Depn Acct,Accum Depn Acct Desc,Accum Depn Sub Acct,DepnExp Acct,"
    "Depn Exp Sub Acct,Depn Exp CC,Depn Method,Depn Type,Life,Opening Balance WDV,"
    "Closing Balance WDV,Opening Balance Assets At Cost,"
    "Additions >$1000,Additions <=$1000,Transfer In - Cost,"
    "Transfer Out - Cost,Disposal Cost,Closing Balance Assets At Cost,"
    "Opening Balance Accum Depn,Depreciation Current Period - Declining Bal,"
    "Depreciation Current Period - Straight Line,"
    "Accum Dep to DOT-Transfer In,Accum Dep to DOT-Transfer Out,"
    "Depn Rev On Disposals,Closing Balance Accum Depn,Proceeds on Disposal"
    skip
    .
    
  for each t_famov no-lock 
    break by famov_domain by famov_fabk_id by famov_entity by famov_chr04 by famov_ast_sub by famov_fa_id:

    put stream outfile unformatted
      famov_entity          ","  /* Entity */                                     
      famov_fabk_id         ","  /* Book */                                       
      famov_fa_id           ","  /* Asset */                                      
      famov_fa_desc         ","  /* Asset Description */                          
      famov_startdt         ","  /* Service Book Date */                          
      famov_startyr         ","  /* Service Period */                             
      famov_dateloaded      ","  /* Date Loaded */                                
      famov_loadyr          ","  /* Loaded Period */                              
      famov_transper        ","  /* Transfer Period */                            
      famov_tr_entity_fr    ","  /* Entity From */                                
      famov_tr_entity_to    ","  /* Entity To */                                  
      famov_disp_dt         ","  /* Disposal Date */                              
      famov_facls_id        ","  /* Class */                                      
      famov_facls_desc      ","  /* Class Desc */                                 
      famov_chr01           ","  /* Stat Class */                                 
      famov_chr03           ","  /* Tax Class */                                  
      famov_ast_acct        ","  /* Asset Acct */                                 
      famov_ast_acct_desc   ","  /* Asset Acct Desc */                            
      famov_ast_sub         ","  /* Asset Sub-Acct */                             
      famov_dep_acct        ","  /* Accum Depn Acct */                            
      famov_dep_acct_desc   ","  /* Accum Depn Acct Desc */                       
      famov_acc_dep_sub     ","  /* Accum Depn Sub Acct */                        
      famov_per_dep_acct    ","  /* DepnExp Acct */                               
      famov_per_dep_sub     ","  /* Depn Exp Sub Acct */                          
      famov_per_dep_cc      ","  /* Depn Exp CC */                                
      famov_dep_method      ","  /* Depn Method */                                
      famov_dep_type        ","  /* Depn Type */                                  
      famov_dep_life        ","  /* Life */                                       
      famov_op_wdv          ","  /* Opening Balance WDV */                        
      famov_cl_wdv          ","  /* Closing Balance WDV */                        
      famov_op_bkcost       ","  /* Opening Balance Assets At Cost */             
      famov_additions_o     ","  /* Additions >$1000 */                           
      famov_additions_u     ","  /* Additions <=$1000 */                          
      famov_in_costAmt      ","  /* Transfer In - Cost */                         
      famov_out_costAmt     ","  /* Transfer Out - Cost */                        
      famov_disposals       ","  /* Disposal Cost */                              
      famov_cl_bkcost       ","  /* Closing Balance Assets At Cost */             
      famov_op_accum_depn   ","  /* Opening Balance Accum Depn */                 
      famov_start_dep_3     ","  /* Depreciation Current Period - Declining Bal */
      famov_start_dep_1_5   ","  /* Depreciation Current Period - Straight Line */
      famov_in_vAccumDepBk  ","  /* Accum Dep to DOT-Transfer In */               
      famov_out_vAccumDepBk ","  /* Accum Dep to DOT-Transfer Out */              
      famov_disp_dep        ","  /* Depn Rev On Disposals */                      
      famov_cl_accum_depn   ","  /* Closing Balance Accum Depn */                 
      famov_proc_on_disp         /* Proceeds on Disposal */                       
      skip
      .  
            
    accumulate 
      famov_op_wdv          (total)
      famov_cl_wdv          (total)
      famov_op_bkcost       (total)
      famov_additions_o     (total)
      famov_additions_u     (total)
      famov_in_costAmt      (total)
      famov_out_costAmt     (total)
      famov_disposals       (total)
      famov_cl_bkcost       (total)
      famov_op_accum_depn   (total)
      famov_start_dep_3     (total)
      famov_start_dep_1_5   (total)
      famov_in_vAccumDepBk  (total)
      famov_out_vAccumDepBk (total)
      famov_disp_dep        (total)
      famov_cl_accum_depn   (total)
      famov_proc_on_disp    (total)
      .
                   
    if last(famov_domain) then
    do:   
      put stream outfile unformatted
        ",,,,,,,,,,,,,,,,,,,,,,,,,,,"
        "================,================,================,================,================,================,================,"
        "================,================,================,================,================,================,================,"
        "================,================,================,================" skip
        ",,,,,,,,,,,,,,,,,,,,,,,,,,," 
        "TOTALS,"
        (accum total famov_op_wdv)          ","
        (accum total famov_cl_wdv)          ","
        (accum total famov_op_bkcost)       ","
        (accum total famov_additions_o)     ","
        (accum total famov_additions_u)     ","
        (accum total famov_in_costAmt)      ","
        (accum total famov_out_costAmt)     ","
        (accum total famov_disposals)       ","
        (accum total famov_cl_bkcost)       ","
        (accum total famov_op_accum_depn)   ","
        (accum total famov_start_dep_3)     ","
        (accum total famov_start_dep_1_5)   ","
        (accum total famov_in_vAccumDepBk)  ","
        (accum total famov_out_vAccumDepBk) ","
        (accum total famov_disp_dep)        ","
        (accum total famov_cl_accum_depn)   ","
        (accum total famov_proc_on_disp)
        .
    end. /* if last(famov_domain) */

  end.
          
END PROCEDURE.