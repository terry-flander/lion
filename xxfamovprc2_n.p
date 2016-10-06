/*------------------------------------------------------------------------

  File:         xxfamovprc2.p

  Description:  Asset Movement Processing for FAS_FAM
                Assets at Cost and Accumulated Depreciation (Extracts)

  History:
  
  Version Date     Author   Description
  ------- -------- -------- ---------------------------------------------
     2.00 07Sep16  Terry    Refactored original
          
------------------------------------------------------------------------*/
{mfdeclre.i}
{xxfa-func.i}

def shared var book         like fabk_id     no-undo label "Book".
def shared var book1        like fabk_id     no-undo label "To".
def shared var entity       like fa_entity   no-undo    label "Entity".
def shared var entity1      like fa_entity   no-undo    label "To".
def shared var asset        like fab_fa_id   no-undo    label "Asset".
def shared var asset1       like fab_fa_id   no-undo    label "To".
def shared var cls          like fa_facls_id no-undo    label "Class".
def shared var cls1         like fa_facls_id no-undo    label "To".
def shared var assacc       like faba_acct   no-undo    label "Asset Account".
def shared var assacc1      like faba_acct   no-undo    label "To".
def shared var depacc       like ast_ac_acct no-undo    label "Accum Depn Account".
def shared var depacc1      like ast_ac_acct no-undo    label "To".
def shared var start_per    like fabd_yrper  no-undo.
def shared var end_per      like fabd_yrper  no-undo.

def shared temp-table t_famov   no-undo
  field famov_domain             like fa_domain
  field famov_entity             like fa_entity
  field famov_fabk_id            like fabk_id
  field famov_fa_id              like fa_id
  field famov_chr04              like fa__chr04                      /*CP01*/
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
  
def temp-table ttBook no-undo
    field tBook as char.

create ttBook. tBook = "BOOK".
create ttBook. tBook = "TAX".
create ttBook. tBook = "KIRN".
create ttBook. tBook = "TAX1".

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
def var accDepr               like fabd_accamt  no-undo.
def var vFirstAssetDep        like fabd_accamt  no-undo.
def var netBook               like fabd_peramt  no-undo.
def var costAmt               like fabd_accamt  no-undo.
def var vAccumDepBk           like fabd_accamt  no-undo.
def var v_glseq               like faba_glseq   no-undo.
def var v_startdt             like fa_startdt   no-undo label 'Date' init today.
def var v_enddt               like fa_startdt   no-undo label 'To'   init today. 
def var i                     as int            no-undo.
def var vAcctDesc             as char           no-undo.
def var vAccumDep             as dec            no-undo.

def buffer b_t_famov   for t_famov.
def buffer b-fabd_det  for fabd_det.
def buffer b1-fab_det  for fab_det.
def buffer bf_fab_det  for fab_det.
def buffer b1-fabd_det for fabd_det.

/* getting some errors but need report to complete */
pause 0 before-hide.

assign
  v_startdt = yearPeriod2Date(global_domain, start_per, true)
  v_enddt   = yearPeriod2Date(global_domain, end_per, false)
  .

for each fa_mstr no-lock 
   where fa_domain   = global_domain
     and fa_entity   >= entity 
     and fa_entity   <= entity1 
     and fa__dte01   >= 09/01/1949
     and fa__dte01   <= v_enddt
     and fa_id       >= asset 
     and fa_id       <= asset1   
     and fa_facls_id >= cls 
     and fa_facls_id <= cls1 
     and (fa_disp_dt  = ? or fa_disp_dt >= v_startdt):

  v_glseq = getLastGLSequence(global_domain, fa_id).
  
  if    filterAccountByType(global_domain, fa_id, "1", ?, assacc, assacc1)
    and filterAccountByType(global_domain, fa_id, "2", ?, depacc, depacc1)
    and filterAccountByType(global_domain, fa_id, "3", v_glseq, "", "_")
    and filterAccountByType(global_domain, fa_id, "4", ?, "", "_") then
  do:
  
    /* Silly counter on screen */
    i = i + 1.
    put screen row 19 string(i,">>>,>>9").

    for each  ttBook
       where tBook >= book
         and tBook <= book1:

      create t_famov.
      assign 
        famov_domain        = fa_domain
        famov_entity        = fa_entity
        famov_fabk_id       = tBook
        famov_fa_id         = fa_id
        famov_chr04         = if tBook = "TAX" then fa__chr03 else fa__chr01
        famov_dep_type      = getDepreciationType(global_domain, fa_id, tBook)
        famov_start_dep     = 0
        famov_start_dep     = 0
        famov_op_accum_depn = 0
        famov_cl_accum_depn = 0
        famov_proc_on_disp  = fa_dispamt
        .

      run getGLAccountByType(fa_domain, fa_id, "1", output famov_ast_acct, output famov_ast_sub, output vAcctDesc).
      run getGLAccountByType(fa_domain, fa_id, "2", output famov_dep_acct, output famov_acc_dep_sub, output vAcctDesc).

      run getDepreciationAmounts(global_domain, fa_id, tBook, start_per, end_per, 
        output famov_op_accum_depn, output famov_start_dep, output famov_cl_accum_depn,
        output famov_variance, output famov_report, output famov_message).

      assign
        vrowid = rowid(t_famov)
        famov_op_bkcost     = f-sumcost(fa_Id,fa_domain,tBook)
        famov_cl_bkcost     = famov_op_bkcost
        famov_op_bkcost     = getBookValue(global_domain, fa_id, tBook, v_startdt)
        .

         
      /* Current period addition */
      if inDateRange(fa__dte01, v_startdt, v_enddt) then
      do:
        assign 
          famov_additions   = famov_cl_bkcost
          famov_additions_o = if  famov_cl_bkcost <= 1000 then 0 else famov_cl_bkcost
          famov_additions_u = if  famov_cl_bkcost > 1000 then 0 else famov_cl_bkcost
          famov_start_dep   = famov_cl_accum_depn
          .
      end. /* new additions */
      
      assign
        famov_start_dep_3   = setDecliningBalance(famov_dep_type, famov_start_dep)
        famov_start_dep_1_5 = setStraightLine(famov_dep_type, famov_start_dep)
        .

      /* Current period disposal */
      if inDateRange(fa_disp_dt, v_startdt, v_enddt) then 
        assign 
          famov_disposals = famov_cl_bkcost
          famov_disp_dep  = famov_cl_accum_depn
          .

      /*Recalculated Closing Bal.Assets at cost */
      assign                                                          
        famov_cl_bkcost       = famov_cl_bkcost - famov_disposals
        famov_cl_accum_depn   = famov_cl_accum_depn - famov_disp_dep
        famov_op_bkcost       = famov_cl_bkcost -  famov_additions +  famov_disposals
        famov_op_accum_depn   = famov_cl_accum_depn - famov_start_dep - famov_adds_dep  + famov_disp_dep
        famov_op_wdv          = famov_op_bkcost - famov_op_accum_depn
        famov_cl_wdv          = famov_cl_bkcost - famov_cl_accum_depn
        .

      {xxfamovprc2_t.i}
      
    end.  /* each ttBook */
    
  end. /* filters */
  
end. /* for each fa_mstr */
