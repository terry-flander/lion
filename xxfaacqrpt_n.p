/*------------------------------------------------------------------------

  File:         xxfaacqrpt.p

  Description:  Asset Acquisition Report
                Reports asset additions and the change in depreciation 
                for the period
 
  History:
  
  Version Date     Author   Description
  ------- -------- -------- ---------------------------------------------
     2.00 07Sep16  Terry    Refactored original
          
------------------------------------------------------------------------*/
{mfdtitle.i}
{xxfa-func.i}

{xxfabkfx.i}  /* MFG/pro function f-sumcost */
{xxfadepfx.i} /* MFG/pro function get-accdep */

def var cls           like facls_id    no-undo  label 'Class'.
def var cls1          like facls_id    no-undo  label 'To'.
def var loc           like faloc_id    no-undo  label 'Location'.
def var loc1          like faloc_id    no-undo  label 'To'.
def var acc           like faba_acct   no-undo  label "Account".
def var acc1          like faba_acct   no-undo  label "To".
def var sub           like faba_sub    no-undo  label "Sub Account" .
def var sub1          like faba_sub    no-undo  label "To".
def var ctr           like faba_cc     no-undo  label "Cost Centre".
def var ctr1          like faba_cc     no-undo  label "To".
def var proj          like faba_proj   no-undo  label "Project #".
def var book          like fabk_id     no-undo  label "Book".
def var entity        like fa_entity   no-undo  label "Entity".
def var entity1       like fa_entity   no-undo  label "To".
def var start_per     as char          no-undo  label "Period"     format 'x(6)'.
def var end_per       as char          no-undo  label "To"         format 'x(6)'.
def var ovr_per       as char          no-undo                     format 'x(6)'.
def var equip         like fad_desc    no-undo  label "Equip No"   format 'x(20)'.
def var v_proj        like faba_proj   no-undo.
def var v_salvamt     like fab_salvamt no-undo.
def var v_start_date  like fa_startdt  no-undo.
def var v_end_date    like fa_startdt  no-undo.
def var v_lstart_date like fa_startdt no-undo.
def var v_glseq       like faba_glseq  no-undo.
def var v_cost        like fabd_accamt no-undo label 'Cost'.
def var v_acc_dep     like fabd_accamt no-undo.
def var v_peramt      like fabd_accamt no-undo label 'Period Depn'.
def var v_asset_acc   like faba_acct   no-undo.
def var v_asset_sub   like faba_sub    no-undo.
def var v_asset_cc    like faba_cc     no-undo.
def var v_accum_acc   like faba_acct   no-undo.
def var v_accum_sub   like faba_sub    no-undo.
def var v_accum_cc    like faba_cc     no-undo.
def var v_expense_acc like faba_acct   no-undo.
def var v_expense_sub like faba_sub    no-undo.
def var v_expense_cc  like faba_cc     no-undo.
def var v_fab_famt_id like fab_famt_id no-undo.
def var v_fab_life    like fab_life    no-undo.
def var v_fab_ovrdt   like fab_ovrdt   no-undo.
def var v_open_acc_dep as dec          no-undo.
def var v_variance     as dec          no-undo.
def var v_report       as log          no-undo.
def var v_message      as char         no-undo.
def var i              as int          no-undo.
def var v_disposals    as dec          no-undo.
def var v_disp_dep     as dec          no-undo.
def var v_disp_date    as char         no-undo.
def buffer b_fabd_det for fabd_det.

def var v_outfile as char format 'x(24)' no-undo label 'Output File'.

def stream v_outstream.

assign
  start_per = date2YearPeriod(global_domain, today)
  end_per   = start_per
  book      = getDefaultBook(global_domain)
  entity    = getDefaultEntity(global_domain, global_userid)
  entity1   = entity
  .

repeat:
  if cls1        = hi_char then cls1      = "".
  if loc1        = hi_char then loc1      = "".
  if acc1        = hi_char then acc1      = "".
  if sub1        = hi_char then sub1      = "".
  if ctr1        = hi_char then ctr1      = "".
  if entity1     = hi_char then entity1   = "".
  
  update
    start_per  colon 20  end_per   colon 45
    skip(1)
    book       colon 20
    entity     colon 20  entity1   colon 45
    proj       colon 20

    equip      colon 20
    skip
    acc        colon 20  acc1      colon 45
    sub        colon 20  sub1      colon 45
    ctr        colon 20  ctr1      colon 45
    skip(1)
    cls        colon 20  cls1      colon 45
    loc        colon 20  loc1      colon 45
    skip(1)
    with frame a side-labels.
  
  assign v_outfile = 'acq' + string(today,'999999') + '.txt'.
  
  update v_outfile colon 20 skip(2) with frame a.
  
  if cls1        = '' then cls1      = hi_char.
  if loc1        = '' then loc1      = hi_char.
  if acc1        = '' then acc1      = hi_char.
  if sub1        = '' then sub1      = hi_char.
  if ctr1        = '' then ctr1      = hi_char.
  if entity1     = '' then entity1   = hi_char.
  
  bcdparm = "".
  {mfquoter.i cls}
  {mfquoter.i cls1}
  {mfquoter.i loc}
  {mfquoter.i loc1}
  {mfquoter.i acc}
  {mfquoter.i acc1}
  {mfquoter.i sub}
  {mfquoter.i sub1}
  {mfquoter.i ctr}
  {mfquoter.i ctr1}
  {mfquoter.i proj}
  {mfquoter.i equip}
  {mfquoter.i book}
  {mfquoter.i entity}
  {mfquoter.i entity1}
  {mfquoter.i start_per}
  {mfquoter.i end_per}
  
  {mfselbpr.i "printer" 132}
  {mfphead.i}
  
  assign
    v_start_date = yearPeriod2Date(global_domain, start_per, true)
    v_lstart_date = yearPeriod2Date(global_domain, end_per, true)
    v_end_date = yearPeriod2Date(global_domain, end_per, false)
    .
  
  if v_outfile <> '' then output stream v_outstream to value(v_outfile).
  
  /* if 'scroll' display is used put a warning to let users know only 3000 *
   * lines will be displayed.                                              */
  if dev = 'scroll' then 
    put 'WARNING: Only 3000 lines are displayed. '
        'For a comprehensive report use the Output File option.' skip(1).
  
/*            1         2         3         4         5         6         7         8         9         0         1         2         3         4        5          6         7 */
/*   12345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890 */
  put 
    'Asset        Description                   Equipment No       Serial No      Serv Date  Cls Loc  Enty    Cost $           Salvage $        Accum Depn $    ' at 1 skip
    '------------ ----------------------------- ------------------ -------------- ---------- --- ---- ------- ---------------- ---------------- ----------------' at 1 skip
    .
                           
  if v_outfile <> '' then                        
    put stream v_outstream unformatted
    'Asset,Description,'
    'Equip No,Serial No,'
    'Serv Date,Date Loaded,Asset Acct,'
    'Asset Sub,Accum Dep Acc,Accum Dep Sub,'
    'Stat Class,Tax Class,Char4,' 
    'Expense Acc, Expense Sub, Expense CC,Project,'
    'Class,Location,Entity,Method,Life,Cost,Salvage,Disp Date,Disposal Cost,Depn,'
    'Dep Rev on Disposals,Accum Depn,Depn Override Date' 
    skip(1).
  
  /* getting some errors but need report to complete */
  pause 0 before-hide.

  for each fa_mstr no-lock
      where fa_entity   >= entity
        and fa_entity   <= entity1
        and fa_domain    = global_domain 
        and fa__dte01   >= v_start_date
        and fa__dte01   <= v_end_date
        and fa_facls_id >= cls
        and fa_facls_id <= cls1
        and fa_faloc_id >= loc
        and fa_faloc_id <= loc1 
        and (fa_disp_dt  = ? or fa_disp_dt >= v_lstart_date),
     last fad_det 
      where fad_domain = fa_domain
        and fad_fa_id  = fa_id  
      break by fa_domain by fa_id:
  
    assign
      v_glseq = getLastGLSequence(fa_domain, fa_id)
      .

    if    filterEquipment(fa_domain, fa_id, equip)
      and filterBook(fa_domain, fa_id, book)  
      and filterProject(fa_domain, fa_id, proj)
      and filterAccount(fa_domain, fa_id, v_glseq, acc, acc1, sub, sub1, ctr, ctr1) then
    do:
      /* Silly counter on screen */
      i = i + 1.
      put screen row 19 string(i,">>>,>>9").

      run getDepreciationAmounts(fa_domain, fa_id, book, start_per, end_per, 
        output v_open_acc_dep, output v_peramt, output v_acc_dep,
        output v_variance, output v_report, output v_message).

      assign
        v_proj        = getAssetProject(fa_domain, fa_id, v_glseq)
        v_salvamt     = getSalvageAmount(fa_domain, fa_id, book)
        v_fab_famt_id = getMethod(fa_domain, fa_id, book)
        v_fab_life    = getLife(fa_domain, fa_id, book)
        v_fab_ovrdt   = getDepreciationOverrideDate(fa_domain, fa_id, book)
        v_cost        = f-sumcost(fa_id, fa_domain, book)
        .
  
      if inDateRange(fa_disp_dt, v_start_date, v_end_date) then
      do:
        assign 
          v_disposals = v_cost
          v_disp_dep  = v_acc_dep
          v_disp_date = string(fa_disp_dt, "99/99/99")
          .
      end.
      else
      do:
        assign 
          v_disposals = 0
          v_disp_dep  = 0
          v_disp_date = ""
          .
      end.

      run getAssetAccountByType(fa_domain, fa_id, v_glseq, "1", output v_asset_acc, output v_asset_sub, output v_asset_cc).
      run getAssetAccountByType(fa_domain, fa_id, v_glseq, "2", output v_accum_acc, output v_accum_sub, output v_accum_cc).
      run getAssetAccountByType(fa_domain, fa_id, v_glseq, "3", output v_expense_acc, output v_expense_sub, output v_expense_cc).
  
      
      put 
        fa_id       format "x(12)"  ' '
        fa_desc1    format "x(30)" ' '
        fad_desc    ' '
        fad_serial  ' '
        fa_startdt  ' '         
        fa_facls_id format 'x(3)' ' '
        fa_faloc_id format 'x(5)' ' '
        fa_entity   '            '
        v_cost - v_disposals     format "$->>>>,>>>,>>9.99"     ' '
        v_salvamt   format "$->>>>,>>>,>>9.99"  '  '
        v_acc_dep - v_disp_dep  format "$->>>>,>>>,>>9.99" 
        skip.
      
      if v_outfile <> '' then        
        put stream v_outstream unformatted
          trim(fa_id)                            ','  /* Asset */             
          trim(fa_desc1)                         ','  /* Description */       
          trim(fad_desc)                         ','  /* Equip No */          
          trim(fad_serial)                       ','  /* Serial No */         
          fa_startdt                             ','  /* Serv Date */         
          fa__dte01                              ','  /* Date Loaded */       
          v_asset_acc                            ','  /* Asset Acct */        
          v_asset_sub                            ','  /* Asset Sub */
          v_accum_acc                            ','  /* Accum Dep Acc */
          v_accum_sub                            ','  /* Accum Dep Sub */
          fa__chr01                              ','  /* Stat Class */
          fa__chr03                              ','  /* Tax Class */
          fa__chr04                              ','  /* Char4 */
          v_expense_acc                          ','  /* Expense Acc */       
          v_expense_sub                          ','  /* Expense Sub */       
          v_expense_cc                           ','  /* Expense CC */        
          v_proj                                 ','  /* Project */           
          fa_facls_id                            ','  /* Class */             
          fa_faloc_id                            ','  /* Location */          
          fa_entity                              ','  /* Entity */            
          v_fab_famt_id                          ','  /* Method */            
          v_fab_life    format '999.999'         ','  /* Life */              
          v_cost - v_disposals format '->>>>>>>>>9.99'  ','  /* Cost */              
          v_salvamt     format '->>>>>>>>>9.99'  ','  /* Salvage */      
          v_disp_date                            ','  /* Disposal Date */
          v_disposals                            ','  /* Disposal Cost */          
          v_peramt      format '->>>>>>>>>9.99'  ','  /* Period Depn */       
          v_disp_dep                             ','  /* Dep Rev on Disposals */          
          v_acc_dep - v_disp_dep  format '->>>>>>>>>9.99'  ','  
                                                      /* Accum Depn */        
          v_fab_ovrdt                                 /* Depn Override Date */
          skip.
      
      accumulate 
        fa_id (count)
        v_cost (total)
        v_salvamt (total)
        v_peramt(total)
        v_acc_dep(total)
        .
              
      if last(fa_domain) then
      do:  
        put skip(1)
            '================' at 125
            '================' at 143
            '================' at 162
            skip
            (accum count fa_id)
            'ASSETS'           at 14
            'TOTALS'           at 104
            (accum total v_cost)    format '$->>>>>>>>>9.99' at 124
            (accum total v_salvamt) format '$->>>>>>>>>9.99' at 142
            (accum total v_acc_dep) format '$->>>>>>>>>9.99' at 161. 
        
        if v_outfile <> '' then
          put stream v_outstream
            unformatted
            skip(1)
            (accum count fa_id)    ',TOTALS,,,,,,,,,,,,,,,,,,,,,,,'
            (accum total v_cost)    format    '$->>>>>>>>>9.99'   ','
            (accum total v_salvamt) format    '$->>>>>>>>>9.99'  ','
            (accum total v_peramt)  format    '$->>>>>>>>>9.99'  ',,'
            (accum total v_acc_dep) format '$->>>>>>>>>9.99' ','
            .
      end.
    end.
          
  end. /* for each fa_mstr */
  hide frame f_addition.
  {mfrtrail.i}
  
  if v_outfile <> '' then
    put stream v_outstream unformatted
      skip(1)
      'Period:,'      start_per ',To:,' end_per skip(1)
      'Book:,'        book                      skip
      'Entity:,'      entity    ',To:,' entity1 skip
      'Project #:,'   proj                      skip(1)
      'Equip #:,'     equip                     skip(1)
      'Account:,'     acc       ',To:,' acc1    skip
      'Sub Account:,' sub       ',To:,' sub1    skip
      'Cost Centre:,' ctr       ',To:,' ctr1    skip(1)
      'Class:,'       cls       ',To:,' cls1    skip
      'Location:,'    loc       ',To:,' loc1    skip(1)
      'Output File:,' v_outfile.
  
  if v_outfile <> '' then output stream v_outstream close.
  
end. /* repeat (report) */