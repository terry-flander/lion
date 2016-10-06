/*------------------------------------------------------------------------

  File:         xxfamovprc2.p

  Description:  Asset Movement Report for FAS_FAM
                Assets at Cost and Accumulated Depreciation (Extracts)

  History:
  
  Version Date     Author   Description
  ------- -------- -------- ---------------------------------------------
     2.00 07Sep16  Terry    Refactored original
          
------------------------------------------------------------------------*/
{mfdtitle.i}
{xxfa-func.i}

FUNCTION formatSummaryLine RETURNS CHARACTER
  (vp_domain as char,vp_fabk_id as char,vp_entity as char,vp_chr04 as char,
   vp_acct as char,vp_fisc_yr as char,vp_fisc_per as char,vp_ast_sub as char,vp_desc as char,
   vp_amount as decimal) FORWARD.

def new shared var book         like fabk_id      no-undo label "Book".
def new shared var book1        like fabk_id      no-undo label "To".
def new shared var entity       like fa_entity    no-undo label "Entity".
def new shared var entity1      like fa_entity    no-undo label "To".
def new shared var asset        like fab_fa_id    no-undo label "Asset".
def new shared var asset1       like fab_fa_id    no-undo label "To".
def new shared var cls          like fa_facls_id  no-undo label "Class".
def new shared var cls1         like fa_facls_id  no-undo label "To".
def new shared var assacc       like faba_acct    no-undo label "Asset Account".
def new shared var assacc1      like faba_acct    no-undo label "To".
def new shared var depacc       like ast_ac_acct  no-undo label "Accum Depn Account".
def new shared var depacc1      like ast_ac_acct  no-undo label "To".
def new shared var start_per    like fabd_yrper   no-undo.
def new shared var end_per      like fabd_yrper   no-undo.
def new shared var fisc_yr      as char           no-undo format "x(4)".
def new shared var fisc_per     as char           no-undo format "x(2)".
def new shared var fisc_yr_int  as int            no-undo format "9999".
def new shared var fisc_per_int as int            no-undo format "99".

def new shared temp-table t_famov no-undo
  field famov_domain             like fa_domain
  field famov_entity             like fa_entity
  field famov_fabk_id            like fabk_id
  field famov_fa_id              like fa_id
  field famov_chr04              like fa__chr04
  field famov_dep_method         like fab_famt_id
  field famov_dep_type           like famt_type
  field famov_ast_acct           like faba_acct
  field famov_ast_sub            like faba_sub
  field famov_dep_acct           like faba_acct
  field famov_acc_dep_sub        like faba_sub
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
  .

def var cyc_mth             as char no-undo init "Oct,Nov,Dec,Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep".
def var vSubCode            as char no-undo.
def var file                as char no-undo format "x(50)". 
def var v_summary           as log  no-undo format "Summary/Detail" init "Summary".
def var v_classTotal        as log  no-undo format "Class/Accounts" init "Class".
def var v_report            as log  no-undo.

def stream outfile.

{gprun.i ""xxstdtabgt.p"" "(""OUTPUT"", vSubCode, output file)"}

assign
  vSubCode = "FAS_FAM_Extract"
  file = if file = "" then "/tmp/" + vSubCode + "_" + trim(global_domain)
         else file + vSubCode + "_" + trim(global_domain)  
  .

mainloop: 
repeat on endkey undo, return:

  EMPTY TEMP-TABLE t_famov.    

  run date2YearAndPeriod(global_domain, today, output fisc_yr_int, output fisc_per_int).

  update
    fisc_yr_int   label "Fiscal Year"           colon 30  
    fisc_per_int  label "Fiscal/Period"         colon 30
    book          colon 30
    book1
    v_summary     label "Summry/Detail"         colon 30
    v_classTotal  label "Total by Class/Account"  colon 30
    skip(1)
    with frame a side-labels.
  
  assign
    fisc_yr   = string(fisc_yr_int,"9999")
    fisc_per  = string(fisc_per_int,"99")
    start_per = fisc_yr + fisc_per
    end_per   = start_per
    .

  update 
    file  label "Output File" 
    help "Extension defaults to csv" 
    colon 20 
    skip(1) 
    with frame a.
   
  assign
    book1   = hi_char when book1 = ""
    entity1 = hi_char when entity1 = ""
    asset1  = hi_char when asset1 = ""
    cls1    = hi_char when cls1 = ""
    assacc1 = hi_char when assacc1 = ""
    depacc1 = hi_char when depacc1 = ""
    bcdparm = ""
    .
  
  
  {mfquoter.i file}
  
  {mfselbpr.i "printer" 132}
  {mfphead.i}

  {gprun.i ""xxfamovprc2_n.p""}
  
  run output-order.

  {mfrtrail.i}

end. /* repeat, mainloop */

PROCEDURE output-order.
  
  if file = "" then return.
  if (file matches "*.csv") then
    file = substring(file,1,length(file) - 4).
  
  output stream outfile to value(file + ".csv").
      
  def var monthName as char no-undo.
  monthName = entry(int(fisc_per),cyc_mth).
  
  if v_summary  then
  do:
    if v_classTotal then
    do:
      {xxfamovext_s.i famov_chr04}
    end.
    else
    do:
      {xxfamovext_s.i famov_ast_acct}
      {xxfamovext_s.i famov_dep_acct}
    end.
  end. /* v_summary  */

  if (not v_summary or v_report) then
  do:
  
    if (v_summary and v_report) then
    do:
      output stream outfile close.
      output stream outfile to value(file + "_err.csv").
    end.
    
    put stream outfile unformatted
      "Domain,Book,Entity,Asset,Class,Fiscal Year,Fiscal Period,Asset Account,Sub Account,Depreciation Account,Opening Balance WDV,Closing Balance WDV,Opening Balance Assets At Cost,Additions >$1000,Additions <=$1000,Transfer In - Cost,Transfer Out - Cost,Disposal Cost,Closing Balance Assets At Cost,Opening Balance Accum Depn,Depreciation Current Period - Declining Bal,Depreciation Current Period - Straight Line,Accum Dep to DOT-Transfer In,Accum Dep to DOT-Transfer Out,Depn Rev On Disposals,Closing Balance Accum Depn,Proceeds on Disposal,Variance,Message"
      skip.
    for each t_famov no-lock
        where famov_report or not v_summary
        by famov_domain 
        by famov_fabk_id 
        by famov_entity 
        by famov_chr04 
        by famov_ast_sub:
        
      put stream outfile unformatted
        famov_domain          ","  /* Domain */                                     
        famov_fabk_id         ","  /* Book */                                       
        famov_entity          ","  /* Entity */                                     
        famov_fa_id           ","  /* Asset */                                        
        famov_chr04           ","  /* Class */                                      
        fisc_yr               ","  /* Fiscal Year  */                                  
        monthName             ","  /* Fiscal Period */                              
        famov_ast_acct        ","  /* Asset Acct */                                 
        famov_ast_sub         ","  /* Asset Sub-Acct */                             
        famov_dep_acct        ","  /* Accum Depn Acct */                            
        famov_op_wdv          ","  /* Opening Balance WDV */                        
        famov_cl_wdv          ","  /* Closing Balance WDV  */                          
        famov_op_bkcost       ","  /* Opening Balance Assets At Cost */             
        famov_additions_o     ","  /* Additions >$1000 */                          
        famov_additions_u     ","  /* Additions <=$1000 */                          
        famov_in_costAmt      ","  /* Transfer In - Cost  */                           
        famov_out_costAmt     ","  /* Transfer Out - Cost */                        
        famov_disposals       ","  /* Disposal Cost */                                
        famov_cl_bkcost       ","  /* Closing Balance Assets At Cost */             
        famov_op_accum_depn   ","  /* Opening Balance Accum Depn  */                   
        famov_start_dep_3     ","  /* Depreciation Current Period - Declining Bal */
        famov_start_dep_1_5   ","  /* Depreciation Current Period - Straight Line  */  
        famov_in_vAccumDepBk  ","  /* Accum Dep to DOT-Transfer In */               
        famov_out_vAccumDepBk ","  /* Accum Dep to DOT-Transfer Out */                
        famov_disp_dep        ","  /* Depn Rev On Disposals */                      
        famov_cl_accum_depn   ","  /* Closing Balance Accum Depn */                   
        famov_proc_on_disp    ","  /* Proceeds on Disposal */
        famov_variance        ","  /* Depreciation Variance */      
        famov_message              /* Accumulated Depreciation Adjustment if any */                       
        skip.    
    end. /* for each t_famov */
  end. /* detail or adjustents */
  
  output stream outfile close.

END PROCEDURE.

FUNCTION formatSummaryLine RETURNS CHARACTER
  (vp_domain as char,vp_fabk_id as char,vp_entity as char, vp_chr04 as char,
   vp_acct as char, vp_fisc_yr as char,vp_monthName as char,vp_ast_sub as char,vp_desc as char,
   vp_amount as decimal):

  def var vr_result as char no-undo.

  if vp_amount <> 0 then
  do:
    vr_result = vp_domain + "|"
      + vp_fabk_id + "|"
      + vp_entity + "|"
      + vp_chr04 + "|" 
      + vp_fisc_yr + "|"
      + vp_monthName + "|"
      + vp_acct + "|" 
      + vp_ast_sub + "|"
      + vp_desc + "|"
      + string(vp_amount).
  end.
  
  return vr_result.
  
END FUNCTION.
   