/*------------------------------------------------------------------------

  File:         xxfamovext_s.i

  Description:  Asset Movement Report for FAS_FAM
                Shared subtotal logic

  History:
  
  Version Date     Author   Description
  ------- -------- -------- ---------------------------------------------
     1.00 07Sep16  Terry    Refactored from revised xxfamovext_n.p
          
------------------------------------------------------------------------*/
  put stream outfile unformatted
    "Domain|Book|Entity|Class|Fiscal Year|Fiscal Period|Account|Sub Account|Line|Amount"
    skip.
  for each t_famov no-lock 
      break
        by famov_domain 
        by famov_fabk_id 
        by famov_entity 
        by {1} 
        by famov_ast_sub:
    
    accumulate   
      famov_op_wdv           (total by famov_ast_sub)
      famov_cl_wdv           (total by famov_ast_sub)
      famov_op_bkcost        (total by famov_ast_sub)
      famov_additions_o      (total by famov_ast_sub)
      famov_additions_u      (total by famov_ast_sub)
      famov_in_costAmt       (total by famov_ast_sub)
      famov_out_costAmt      (total by famov_ast_sub)
      famov_disposals        (total by famov_ast_sub)
      famov_cl_bkcost        (total by famov_ast_sub)
      famov_op_accum_depn    (total by famov_ast_sub)
      famov_start_dep_3      (total by famov_ast_sub)
      famov_start_dep_1_5    (total by famov_ast_sub)
      famov_in_vAccumDepBk   (total by famov_ast_sub)
      famov_out_vAccumDepBk  (total by famov_ast_sub)
      famov_disp_dep         (total by famov_ast_sub)
      famov_cl_accum_depn    (total by famov_ast_sub)
      famov_proc_on_disp     (total by famov_ast_sub)
      .
      
    if famov_report then v_report = true.

    if last-of(famov_ast_sub) then 
    do:
      if "{1}" = "famov_ast_acct" or "{1}" = "famov_chr04" then
      do:
        put stream outfile unformatted 
          formatSummaryLine(
          famov_domain,famov_fabk_id,famov_entity,famov_chr04,famov_ast_acct,fisc_yr,monthName,famov_ast_sub,
          "Opening Balance WDV",(accum total by famov_ast_sub famov_op_wdv)) skip.
        put stream outfile unformatted 
          formatSummaryLine (
          famov_domain,famov_fabk_id,famov_entity,famov_chr04,famov_ast_acct,fisc_yr,monthName,famov_ast_sub,
          "Closing Balance WDV",(accum total by famov_ast_sub famov_cl_wdv)) skip.
        put stream outfile unformatted 
          formatSummaryLine (
          famov_domain,famov_fabk_id,famov_entity,famov_chr04,famov_ast_acct,fisc_yr,monthName,famov_ast_sub,
          "Opening Balance Assets At Cost",(accum total by famov_ast_sub famov_op_bkcost)) skip.
        put stream outfile unformatted 
          formatSummaryLine (
          famov_domain,famov_fabk_id,famov_entity,famov_chr04,famov_ast_acct,fisc_yr,monthName,famov_ast_sub,
          "Additions >$1000",(accum total by famov_ast_sub famov_additions_o)) skip.
        put stream outfile unformatted 
          formatSummaryLine (
          famov_domain,famov_fabk_id,famov_entity,famov_chr04,famov_ast_acct,fisc_yr,monthName,famov_ast_sub,
          "Additions <=$1000",(accum total by famov_ast_sub famov_additions_u)) skip.
        put stream outfile unformatted 
          formatSummaryLine (
          famov_domain,famov_fabk_id,famov_entity,famov_chr04,famov_ast_acct,fisc_yr,monthName,famov_ast_sub,
          "Transfer In - Cost",(accum total by famov_ast_sub famov_in_costAmt)) skip.
        put stream outfile unformatted 
          formatSummaryLine (
          famov_domain,famov_fabk_id,famov_entity,famov_chr04,famov_ast_acct,fisc_yr,monthName,famov_ast_sub,
          "Transfer Out - Cost",(accum total by famov_ast_sub famov_out_costAmt)) skip.
        put stream outfile unformatted 
          formatSummaryLine (
          famov_domain,famov_fabk_id,famov_entity,famov_chr04,famov_ast_acct,fisc_yr,monthName,famov_ast_sub,
          "Disposal Cost",(accum total by famov_ast_sub famov_disposals)) skip.
        put stream outfile unformatted 
          formatSummaryLine (
          famov_domain,famov_fabk_id,famov_entity,famov_chr04,famov_ast_acct,fisc_yr,monthName,famov_ast_sub,
          "Closing Balance Assets At Cost",(accum total by famov_ast_sub famov_cl_bkcost)) skip.
        put stream outfile unformatted 
          formatSummaryLine (
          famov_domain,famov_fabk_id,famov_entity,famov_chr04,famov_ast_acct,fisc_yr,monthName,famov_ast_sub,
          "Proceeds on Disposal",(accum total by famov_ast_sub famov_proc_on_disp)) skip.
      end.
      if "{1}" = "famov_dep_acct" or "{1}" = "famov_chr04" then
      do:
      
        put stream outfile unformatted 
          formatSummaryLine (
          famov_domain,famov_fabk_id,famov_entity,famov_chr04,famov_dep_acct,fisc_yr,monthName,famov_ast_sub,
          "Opening Balance Accum Depn",(accum total by famov_ast_sub famov_op_accum_depn)) skip.
        put stream outfile unformatted 
          formatSummaryLine (
          famov_domain,famov_fabk_id,famov_entity,famov_chr04,famov_dep_acct,fisc_yr,monthName,famov_ast_sub,
          "Depreciation Current Period - Declining Bal",(accum total by famov_ast_sub famov_start_dep_3)) skip.
        put stream outfile unformatted 
          formatSummaryLine (
          famov_domain,famov_fabk_id,famov_entity,famov_chr04,famov_dep_acct,fisc_yr,monthName,famov_ast_sub,
          "Depreciation Current Period - Straight Line",(accum total by famov_ast_sub famov_start_dep_1_5)) skip.
        put stream outfile unformatted 
          formatSummaryLine (
          famov_domain,famov_fabk_id,famov_entity,famov_chr04,famov_dep_acct,fisc_yr,monthName,famov_ast_sub,
          "Accum Dep to DOT-Transfer In",(accum total by famov_ast_sub famov_in_vAccumDepBk)) skip.
        put stream outfile unformatted 
          formatSummaryLine (
          famov_domain,famov_fabk_id,famov_entity,famov_chr04,famov_dep_acct,fisc_yr,monthName,famov_ast_sub,
          "Accum Dep to DOT-Transfer Out",(accum total by famov_ast_sub famov_out_vAccumDepBk)) skip.
        put stream outfile unformatted 
          formatSummaryLine (
          famov_domain,famov_fabk_id,famov_entity,famov_chr04,famov_dep_acct,fisc_yr,monthName,famov_ast_sub,
          "Depn Rev On Disposals",(accum total by famov_ast_sub famov_disp_dep)) skip.
        put stream outfile unformatted 
          formatSummaryLine (
          famov_domain,famov_fabk_id,famov_entity,famov_chr04,famov_dep_acct,fisc_yr,monthName,famov_ast_sub,
          "Closing Balance Accum Depn",(accum total by famov_ast_sub famov_cl_accum_depn)) skip.
      end.
    end. /* if  last-of(famov_ast_sub) */
    
  end. /* for each t_famov */