/*------------------------------------------------------------------------

  File:         xxfamovprc.p

  Description:  Asset Movement Processing
                Assets at Cost and Accumulated Depreciation (Extracts)

  History:
  
  Version Date     Author   Description
  ------- -------- -------- ---------------------------------------------
     2.00 07Sep16  Terry    Refactored original
          
------------------------------------------------------------------------*/
{mfdtitle.i}
{xxfa-func.i}

def shared var entity           like fa_entity   label "Entity".
def shared var entity1          like fa_entity   label "To".               
def shared var asset            like fab_fa_id   label "Asset".
def shared var asset1           like fab_fa_id   label "To".
def shared var cls              like fa_facls_id label "Class".
def shared var cls1             like fa_facls_id label "To".
def shared var assacc           like faba_acct   label "Asset Account".
def shared var assacc1          like faba_acct   label "To".
def shared var depacc           like ast_ac_acct label "Accum Depn Account".
def shared var depacc1          like ast_ac_acct label "To".
def shared var method           like fab_famt_id label "Method".
def shared var method1          like fab_famt_id label "To".
def shared var pass_domain      like fa_domain.
def shared var pass_book        like fabk_id.
def shared var start_per        like fabd_yrper.
def shared var end_per          like fabd_yrper.

def shared temp-table t_famov
  field famov_domain             like fa_domain
  field famov_entity             like fa_entity
  field famov_fabk_id            like fabk_id
  field famov_fa_id              like fa_id
  field famov_fa_desc            like fa_desc1
  field famov_startdt            like fa_startdt
  field famov_disp_dt            like fa_disp_dt
  field famov_chr01              like fa__chr01                      /*CP01*/
  field famov_chr02              like fa__chr02
  field famov_chr03              like fa__chr03                      /*CP01*/
  field famov_chr04              like fa__chr04                      /*CP01*/
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

/* MFG/pro function f-sumcost */
{xxfadepfx.i} /* CALCULATE DEPRECIATION FUNCTIONS */

/* MFG/pro function get-accdep */
{xxfabkfx.i}  /* CALCULATE SUM OF BASIS FUNCTION */

def var vrowid                as  rowid         no-undo.  
def var vOldEntity            like fabd_entity  no-undo.  
def var vNewEntity            like fabd_entity  no-undo.  
def var vOldSub               like faba_sub     no-undo.  
def var vNewSub               like faba_sub     no-undo.  
def var vOldCC                like faba_cc      no-undo.  
def var vNewCC                like faba_cc      no-undo.  
def var vTransper             like fabd_yrper   no-undo.  
def var costAmt               like fabd_peramt  no-undo.
def var vAccumDepBk           like fabd_accamt  no-undo.     
def var accDepr               like fabd_accamt  no-undo.
def var vFirstAssetDep        like fabd_accamt  no-undo.
def var netBook               like fabd_peramt  no-undo.
def var v_glseq               like faba_glseq   no-undo.
def var i    			      as int            no-undo.
def var v_startdt             like fa_startdt   no-undo. 
def var v_enddt               like fa_startdt   no-undo. 
def var vAccumDep             as dec            no-undo.

def buffer b_t_famov          for t_famov.
def buffer b-fabd_det         for fabd_det.

/* getting some errors but need report to complete */
pause 0 before-hide.

assign
  v_startdt = yearPeriod2Date(pass_domain, start_per, true)
  v_enddt   = yearPeriod2Date(pass_domain, end_per, false)
  .

for each fa_mstr no-lock
  where fa_domain   = pass_domain
    and fa_entity   >= entity 
    and fa_entity   <= entity1 
    and fa__dte01   >= 09/01/1949
    and fa__dte01   <= v_enddt
    and fa_id       >= asset 
    and fa_id       <= asset1   
    and fa_facls_id >= cls 
    and fa_facls_id <= cls1 
    and (fa_disp_dt  = ? or fa_disp_dt >= v_startdt)
  by fa_entity by fa_facls_id:

    i = i + 1.
    PUT SCREEN ROW 19 STRING(i,">>>,>>9").

    assign
      v_glseq = getLastGLSequence(fa_domain, fa_id)
      .

  if    filterBook(fa_domain, fa_id, pass_book)  
    and filterAccountByType(fa_domain, fa_id, "1", ?, assacc, assacc1)
    and filterAccountByType(fa_domain, fa_id, "2", ?, depacc, depacc1)
    and filterAccountByType(fa_domain, fa_id, "3", v_glseq, "", "_")
    and filterAccountByType(fa_domain, fa_id, "4", ?, "", "_") then
  do:
    /* There was a test to see if there are any books of this type in the domain. Should be done at selection */

    create t_famov.
    assign 
      famov_domain        = fa_domain
      famov_entity        = fa_entity
      famov_fabk_id       = pass_book
      famov_fa_id         = fa_id
      famov_fa_desc       = fa_desc
      famov_chr01         = fa__chr01
      famov_chr03         = fa__chr03
      famov_chr04         = if pass_book = "TAX" then fa__chr03 else fa__chr01
      famov_startdt       = getBookStartDate(fa_domain, fa_id, pass_book, fa_startdt)
      famov_startyr       = date2YearPeriod(fa_domain, famov_startdt)
      famov_loadyr        = date2YearPeriod(fa_domain, fa__dte01)
      famov_dateloaded    = fa__dte01
      famov_dep_method    = getMethod(fa_domain, fa_id, pass_book)
      famov_dep_type      = getDepreciationType(global_domain, fa_id, pass_book)
      famov_dep_life      = getLife(fa_domain, fa_id, pass_book)
      famov_disp_dt       = fa_disp_dt
      famov_facls_id      = fa_facls_id
      famov_facls_desc    = getAssetClassDescription(fa_domain, fa_facls_id)
      famov_start_dep     = 0
      famov_adds_dep      = 0
      famov_disp_dep      = 0
      famov_op_accum_depn = 0
      famov_cl_accum_depn = 0
      famov_proc_on_disp  = fa_dispamt
      .

    vrowid = rowid(t_famov).
    run getGLAccountByType(fa_domain, fa_id, "1", output famov_ast_acct, output famov_ast_sub, output famov_ast_acct_desc).
    run getGLAccountByType(fa_domain, fa_id, "2", output famov_dep_acct, output famov_acc_dep_sub, output famov_dep_acct_desc).
    run getAssetAccountByType(fa_domain, fa_id, "3", ?, output famov_per_dep_acct, output famov_per_dep_sub, output famov_per_dep_cc).

    run getDepreciationAmounts(fa_domain, fa_id, pass_book, start_per, end_per, 
      output famov_op_accum_depn, output famov_start_dep, output famov_cl_accum_depn,
      output famov_variance, output famov_report, output famov_message).

    assign
      famov_op_bkcost     = f-sumcost(fa_Id,fa_domain,pass_book)
      famov_cl_bkcost     = f-sumcost(fa_id,fa_domain,pass_book)
      .

    /* Recalculate Opening Bal Assets */
    if getBookValue(fa_domain, fa_id, pass_book, v_startdt) = 0 then famov_op_bkcost = 0.

    /* Asset additions in the curent period */
    if inDateRange(fa__dte01,v_startdt,v_enddt) then
    do:
      assign 
        famov_additions   = famov_cl_bkcost
        famov_additions_o = if famov_cl_bkcost <= 1000 then 0 else famov_cl_bkcost
        famov_additions_u = if famov_cl_bkcost > 1000  then 0 else famov_cl_bkcost
        famov_start_dep   = famov_cl_accum_depn
       .
    end. /* new additions */
    
    assign
      famov_start_dep_3   = setDecliningBalance(famov_dep_type, famov_start_dep)
      famov_start_dep_1_5 = setStraightLine(famov_dep_type, famov_start_dep)
      .

    /* Asset Disposed in Reporting Period */
    if inDateRange(fa_disp_dt, v_startdt, v_enddt) then
    do:
      assign 
        famov_disposals = famov_cl_bkcost
        famov_disp_dep  = famov_cl_accum_depn
        .
    end.

    /*Recalculated Closing Bal.Assets at cost */
    assign
      famov_cl_bkcost     = famov_cl_bkcost     - famov_disposals
      famov_cl_accum_depn = famov_cl_accum_depn - famov_disp_dep
      famov_op_bkcost     = famov_cl_bkcost     - famov_additions    +  famov_disposals
      famov_op_accum_depn = famov_cl_accum_depn - famov_start_dep    -  famov_adds_dep    + famov_disp_dep
      famov_op_wdv        = famov_op_bkcost     - famov_op_accum_depn
      famov_cl_wdv        = famov_cl_bkcost     - famov_cl_accum_depn
     .

    {xxfamovprc_t.i}

   end.

end. /* for each fa_mstr */