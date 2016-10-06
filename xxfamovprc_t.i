/*------------------------------------------------------------------------

  File:         xxfamovprc_t.i

  Description:  Asset Movement Processing for FAS_FAM - Asset Transfer
  
                Determine if asset has been transferred as indicated by location change. 
                Should be able to manage more than one change across periods.

                For each transfer record, if fully depreciated before transfer then do nothing,
                otherwise check for entry change. If same entity also do nothing.

  History:
  
  Version Date     Author   Description
  ------- -------- -------- ---------------------------------------------
     2.00 09Sep16  Terry    Refactored original
          
------------------------------------------------------------------------*/
  def var vVariance   as dec  no-undo.
  def var vReport     as char no-undo.
  def var vMessage    as char no-undo.

  for each fabd_det
      fields(fabd_domain fabd_fa_id fabd_faloc_id fabd_entity fabd_yrper) no-lock
      where fabd_domain   = pass_domain
        and fabd_fa_id    = fa_id
        and fabd_transfer = yes
        and fabd_yrper    >= start_per
        and fabd_yrper    <= end_per
        and fabd_fabk_id  = pass_book
      break by fabd_yrper by fabd_faloc_id:
      
    if  last-of(fabd_faloc_id) then
    do:
      run getDepreciationAmounts(pass_domain, fabd_fa_id, pass_book, fabd_yrper, 
        output vAccumDepBk, output vFirstAssetdep, output accDepr,
        output vVariance, output vReport, output vMessage).

      assign
        costAmt = getBookValue(pass_domain, fabd_fa_id, pass_book, v_enddt)
        netBook = costAmt - accDepr
        .
    
      if netBook >= 0 then
      do:
        find last b-fabd_det no-lock
            where b-fabd_det.fabd_domain = fabd_det.fabd_domain
              and b-fabd_det.fabd_fa_id  = fabd_det.fabd_fa_id
              and b-fabd_det.fabd_yrper  < fabd_det.fabd_yrper no-error.
        if available b-fabd_det and b-fabd_det.fabd_entity <> fabd_det.fabd_entity then
        do:
    
          run getLocationAccount(fabd_det.fabd_domain, fabd_det.fabd_faloc_id, fabd_det.fabd_entity, output vOldSub, output vOldCC).  
          run getLocationAccount(b-fabd_det.fabd_domain, b-fabd_det.fabd_faloc_id, b-fabd_det.fabd_entity, output vNewSub, output vNewCC).  
  
          assign
            vOldEntity     = b-fabd_det.fabd_entity
            vNewEntity     = fabd_det.fabd_entity
            vTransPer      = fabd_det.fabd_yrper
            .
  
          buffer-copy t_famov to b_t_famov.
    
          find t_famov where rowid(t_famov) = vrowid no-error.
          if available t_famov then
            assign
              b_t_famov.famov_acc_dep_sub    = vOldSub
              b_t_famov.famov_ast_sub        = vOldSub
              b_t_famov.famov_entity         = vNewEntity
              b_t_famov.famov_in_costAmt     = costAmt
              b_t_famov.famov_in_vAccumDepBk = vAccumDepBk
              b_t_famov.famov_op_accum_depn  = 0
              b_t_famov.famov_op_bkcost      = 0
              b_t_famov.famov_op_wdv         = 0
              b_t_famov.famov_per_dep_cc     = vOldCC
              b_t_famov.famov_per_dep_sub    = vOldSub
              b_t_famov.famov_start_dep      = b_t_famov.famov_start_dep - vFirstAssetdep
              b_t_famov.famov_transper       = vTransPer
              b_t_famov.famov_tr_entity_fr   = vOldEntity
              b_t_famov.famov_tr_entity_to   = vNewEntity
              b_t_famov.famov_start_dep_1_5  = setStraightLine(famov_dep_type, b_t_famov.famov_start_dep)
              b_t_famov.famov_start_dep_3    = setDecliningBalance(famov_dep_type, b_t_famov.famov_start_dep)
              
              t_famov.famov_acc_dep_sub      = vNewSub
              t_famov.famov_ast_sub          = vNewSub
              t_famov.famov_cl_accum_depn    = 0
              t_famov.famov_cl_bkcost        = 0 
              t_famov.famov_cl_wdv           = 0 
              t_famov.famov_entity           = vOldEntity
              t_famov.famov_out_costAmt      = costAmt
              t_famov.famov_out_vAccumDepBk  = vAccumDepBk
              t_famov.famov_per_dep_cc       = vNewCC
              t_famov.famov_per_dep_sub      = vNewSub
              t_famov.famov_start_dep        = vFirstAssetdep
              t_famov.famov_transper         = vTransPer
              t_famov.famov_tr_entity_fr     = vOldEntity
              t_famov.famov_tr_entity_to     = vNewEntity
              t_famov.famov_start_dep_1_5    = setStraightLine(famov_dep_type, t_famov.famov_start_dep)
              t_famov.famov_start_dep_3      = setDecliningBalance(famov_dep_type, t_famov.famov_start_dep)
              .
    
        end. /* Entity changed */
  
      end. /* if netBook > 0 */
  
    end. /* if last-of(fabd_faloc_id) */
  
  end. 
