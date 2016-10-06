/*------------------------------------------------------------------------

  File:         xxscdfrpt_n.p

  Description:  Direct Freight Recovery Report
                
  History:
  
  Version Date     Author   Description
  ------- -------- -------- ---------------------------------------------
     1.00 05Oct16  Terry    Structure from xxscsrrpt_n.p (Shuttle Recovery)
          
------------------------------------------------------------------------*/

{mfdtitle.i "3"}

def var dateFrom        as date no-undo.
def var dateTo          as date no-undo.
def var csvFileName     as char no-undo init "DFRecovery".
def var okToOv          as log   no-undo.
def var wkDir           as char no-undo format "x(60)".

def stream csv.
def stream wkd.

def temp-table ttResult no-undo
  field tt_nbr            like ih_nbr        /* Sales Order */
  field tt_inv_nbr        like ih_inv_nbr    /* Invoice */
  field tt_inv_date       like ih_inv_date   /* Invoice Date */
  field tt_ih_cust        like ih_cust       /* Customer Number */
  field tt_cm_sort        like cm_sort       /* Customer Name */
  field tt_entity         like gltr_entity
  field tt_acc            like gltr_acc
  field tt_sub            like gltr_sub
  field tt_ctr            like gltr_ctr
  field tt_idh_line       like idh_line      /* Invoice Line Number */
  field tt_idh_part       like idh_part      /* SKU */
  field tt_pt_desc1       like pt_desc1      /* Part Description */ 
  field tt_idh_qty_inv    like idh_qty_inv   /* Qty Invoiced */
  field tt_cm_site        like cm_site       /* Customer Site */
  field tt_idh_site       like idh_site      /* Line Site */
  field tt_lineHaulStd    as dec             /* Line Haul Std */
  field tt_directRecAmt   as dec             /* Exended amount */
  .

FUNCTION getState RETURNS CHARACTER 
  (vp_site as char) FORWARD.
FUNCTION getEntity RETURNS CHARACTER 
  (vp_domain as char, vp_site as char) FORWARD.
FUNCTION interStateTransfer RETURNS LOGICAL 
  (vp_domain as char, vp_fromSite as char, vp_toSite as char) FORWARD.
FUNCTION getLinehaulStandard RETURNS DECIMAL 
  (vp_domain as char, vp_site as char, vp_part as char) FORWARD.
FUNCTION getConversionFactor RETURNS DECIMAL
  (vp_domain as char, vp_fromUm as char, vp_toUm as char, vp_part as char, vp_reverse as log) FORWARD.
FUNCTION convertAmount RETURNS DECIMAL
  (vp_domain as char, vp_toUm as char, vp_fromUm as char, vp_part as char, vp_amount as dec) FORWARD.

form
  skip(1)
  dateFrom         colon 20                      label "Invoice Date"
  dateTo           colon 45                      label "To"
  skip(1)
  csvFileName      colon 20 format "x(40)"       label "File Name"
  skip
  with frame a side-labels width 80
  title " Direct Freight Recovery Report "
  .

input stream wkd thru echo $WKD no-echo.
import stream wkd unformatted wkDir.
input stream wkd close.

csvFileName = wkdir + "/" + csvFileName.

find last glc_cal where glc_domain = global_domain
                  and   glc_end    < date(month(today),01,year(today))
                  no-lock no-error.

if available glc_cal then
do:
   assign 
      dateFrom = glc_start
      dateTo   = glc_end.

   display 
      dateFrom
      dateTo
   with frame a.
end.

repeat:
  assign
    dateFrom  = if dateFrom = low_date then ? else dateFrom
    dateTo    = if dateTo = hi_date then ? else dateTo
    .

  update
    dateFrom
    dateTo
    csvFileName
    with frame a.

  if csvFileName = "" then
  do:
      message "ERROR: FILE NAME CANNOT BE BLANK. Please re-enter.".
      next-prompt csvFileName with frame a.
      undo, retry.
  end.
  
  if search(csvFileName + "-Detail.csv") <> ? and not batchrun then 
  do:
    message "WARNING: FILE ALREADY EXISTS. OK to override?" update okToOv.
    if okToOv = ? or okToOv = no then
        undo, retry.
  end.

  bcdparm = "".
  {mfquoter.i dateFrom}
  {mfquoter.i dateTo}
  {mfquoter.i csvFileName}

  assign
    dateFrom  = if dateFrom = ? then low_date else dateFrom
    dateTo    = if dateTo = ? then hi_date else dateTo
    .
    
  {mfselbat.i}

  status default "Extract now running. Please wait ...".
  
  run loadResult.
  run createDetailReport.
  run createSummaryReport.
  run createJournalReport.

  runok = yes.
  status default.
  
  if not batchrun then 
  do:
    if index(csvFileName,"/") > 0 then
      message "File" substring(csvFileName,r-index(csvFileName,"/") + 1)
              "has been created in directory"
              substring(csvFileName,1,r-index(csvFileName,"/") - 1)
              "."
              view-as alert-box.
    else message "File" csvFileName "has been created in your home directory."
               view-as alert-box.
  end.
end.

PROCEDURE loadResult: 

  def var vl_line             as int no-undo.
  def var vl_lineHaulStandard as dec no-undo.
  def var vl_directRecAmt     as dec no-undo.
  
  EMPTY TEMP-TABLE ttResult.
  for each ih_hist no-lock
      where ih_domain = global_domain
        and ih_inv_date >= dateFrom 
        and ih_inv_date <= dateTo,
    first cm_mstr no-lock
      where cm_domain = ih_domain
        and cm_addr = ih_cust,
    each idh_hist no-lock
      where idh_hist.idh_domain  = ih_hist.ih_domain
        and idh_hist.idh_inv_nbr = ih_hist.ih_inv_nbr
        and idh_hist.idh_nbr     = ih_hist.ih_nbr
        and idh_hist.idh_um      = "CN", /* TODO: Check on containers */
    first pt_mstr no-lock
      where pt_domain = ih_domain
        and pt_part   = idh_part
    by ih_nbr:
    
    if interStateTransfer(ih_domain, idh_site, cm_site) then
    do:
      assign
        vl_lineHaulStandard = convertAmount(ih_domain, idh_um, pt_um, idh_part, getLinehaulStandard(ih_domain, idh_site, idh_part))
        vl_directRecAmt     = round(vl_lineHaulStandard * idh_qty_inv, 2)
        .
  
      create ttResult.
      assign
        tt_entity        = getEntity(ih_domain, cm_site)   
                                                /* Entity from Customer Site */
        tt_acc           = idh_acct
        tt_sub           = idh_sub
        tt_ctr           = idh_cc
        tt_nbr           = ih_nbr               /* Sales Order */
        tt_inv_nbr       = ih_inv_nbr           /* Invoice */
        tt_inv_date      = ih_inv_date          /* Invoice Date */
        tt_ih_cust       = ih_cust              /* Customer Number */
        tt_cm_sort       = cm_sort              /* Customer Name */
        tt_idh_line      = idh_line             /* Invoice Line Number */
        tt_idh_part      = idh_part             /* SKU */
        tt_pt_desc1      = pt_desc1             /* Part Description */ 
        tt_idh_qty_inv   = idh_qty_inv          /* Qty Shipped */
        tt_cm_site       = cm_site              /* Customer Site */
        tt_idh_site      = idh_site             /* Line Site */
        tt_lineHaulStd   = vl_lineHaulStandard  /* Line Haul Std */
        tt_directRecAmt  = vl_directRecAmt      /* Direct Freight Recovery Amount */
        .
    end.
  end.

END PROCEDURE.

PROCEDURE createDetailReport:

  output stream csv to value(csvFileName + "-Detail.csv").

  export stream csv delimiter ","
    "Interstate Orders with Direct Freight"
    .
  export stream csv delimiter ","
    "Order"
    "Invoice"
    "Invoice Date"
    "Cust"
    "Name"
    "Product"
    "Description"
    "Quantity"
    "Cust Site"
    "Dist Site"
    "HD Linehaul"
    "Direct Recovery"
    .
         
  for each ttResult
      where tt_lineHaulStd <> 0
    by tt_cm_site:
    export stream csv delimiter ","
      tt_nbr          
      tt_inv_nbr      
      tt_inv_date     
      tt_ih_cust      
      tt_cm_sort      
      tt_idh_part     
      tt_pt_desc1     
      tt_idh_qty_inv 
      tt_cm_site      
      tt_idh_site     
      tt_lineHaulStd  
      string(tt_directRecAmt,"->>>,>>>,>>9.99") 
      .
  end.

  export stream csv delimiter ","
    skip (2)
    "Interstate Orders with NO Direct Freight"
    .
  export stream csv delimiter ","
    "Order"
    "Invoice"
    "Invoice Date"
    "Cust"
    "Name"
    "Product"
    "Description"
    "Quantity"
    "Cust Site"
    "Dist Site"
    "HD Linehaul"
    "Direct Recovery"
    .
  for each ttResult
      where tt_lineHaulStd = 0
    by tt_cm_site:
    export stream csv delimiter ","
      tt_nbr          
      tt_inv_nbr      
      tt_inv_date     
      tt_ih_cust      
      tt_cm_sort      
      tt_idh_part     
      tt_pt_desc1     
      tt_idh_qty_inv 
      tt_cm_site      
      tt_idh_site     
      tt_lineHaulStd  
      string(tt_directRecAmt,"->>>,>>>,>>9.99") 
      .
  end.
         
  output stream csv close.

END PROCEDURE.

PROCEDURE createSummaryReport:
  
  output stream csv to value(csvFileName + "-Summary.csv").

  export stream csv delimiter ","
    "Cust Site"
    "Dist Site"
    "Direct Freight Recovery"
    .
         
  for each ttResult
      where tt_directRecAmt <> 0
    break by tt_cm_site by tt_idh_site:
    
    accumulate tt_directRecAmt (total by tt_cm_site by tt_idh_site).
    
    if last-of(tt_idh_site) then
    do:
      export stream csv delimiter ","
        tt_cm_site
        tt_idh_site 
        string(accum total by tt_idh_site tt_directRecAmt, "->>>,>>>,>>9.99")
        .
    end.
    
    if last(tt_cm_site) then
    do:
      export stream csv delimiter ","
        ""
        ""
        string(accum total tt_directRecAmt, "->>>,>>>,>>9.99")
        .
    end.
    
  end.
  output stream csv close.

END PROCEDURE.

PROCEDURE createJournalReport:
  
  def var vl_lineDesc as char no-undo.
  def var vl_line     as int  no-undo.
  
  output stream csv to value(csvFileName + "-Journal.csv").

  export stream csv delimiter ","
    "Line Number"
    "Entity"
    "Account"
    "Sub-Account"
    "Cost Centre"
    "Project"
    "Customer"
    "Value"
    "Description"
    "Product"
    "Value"
    "Description"
    "Line Description"
    "Document"
    "Address"
    "Amount"
    ""
    "Entity"
    "Account"
    "Sub-Account"
    "Cost Centre"
    "Project"
    "Customer"
    "Value"
    "Description"
    "Product"
    "Value"
    "Description"
    "Line Description"
    "Document"
    "Address"
    "Amount"
    .
         
  for each ttResult
    where tt_directRecAmt <> 0
    by tt_entity by tt_sub by tt_ctr:
    
    assign
      vl_line = vl_line + 1
      vl_lineDesc = "DFRec. " + tt_cm_site + " ex " + tt_idh_site
      .
    
    export stream csv delimiter ","
      vl_line
      tt_entity     
      "6226"        
      tt_sub        
      tt_ctr
      ""
      ""
      tt_ih_cust
      ""
      ""
      tt_idh_part 
      ""
      vl_lineDesc
      ""
      ""
      string(tt_directRecAmt,"->>>,>>>,>>9.99")
      "" 
      tt_entity     
      "6108"
      tt_sub        
      "3570"
      ""
      ""
      ""
      ""
      ""
      ""
      ""
      vl_lineDesc
      ""
      ""
      string(tt_directRecAmt * -1,"->>>,>>>,>>9.99")
      .
  end.
  output stream csv close.

END PROCEDURE.

FUNCTION getState RETURNS CHARACTER
 (vp_site as char):

  return (     if vp_site begins "TN" then "NSW"
          else if vp_site begins "SA" then "SA"
          else if vp_site begins "SW" then "WA"
          else if vp_site begins "TV" then "VIC"
          else if vp_site begins "CP" then "QLD"
          else "?").

END FUNCTION.

FUNCTION getEntity RETURNS CHARACTER
 (vp_domain as char, vp_site as char):

  def var vl_result as char no-undo.
  
  find first si_mstr no-lock
    where si_domain = vp_domain
      and si_site   = vp_site no-error.
  if available si_mstr then
    vl_result = si_entity.
    
  return vl_result.
  
END FUNCTION.

FUNCTION interStateTransfer RETURNS LOGICAL
  (vp_domain as char, vp_fromSite as char, vp_toSite as char):

  return getEntity(vp_domain, vp_fromSite) <> getEntity(vp_domain, vp_toSite).
  
END FUNCTION.

FUNCTION getLinehaulStandard RETURNS DECIMAL
  (vp_domain as char, vp_site as char, vp_part as char):
  
  def var vp_result   as dec no-undo.
  
  find first spt_det no-lock
    where spt_domain  = vp_domain
      and spt_site    = vp_site
      and spt_sim     = "standard"
      and spt_part    = vp_part 
      and spt_element = "Linehaul" no-error.
  if available spt_det then
    vp_result = spt_cst_tl.

    return vp_result.

END FUNCTION.

FUNCTION getConversionFactor RETURNS DECIMAL
  (vp_domain as char, vp_fromUm as char, vp_toUm as char, vp_part as char, vp_reverse as log):

  def buffer um_mstr for um_mstr.
  
  def var vl_result as dec no-undo init ?.
  
  for first um_mstr
      fields( um_domain um_alt_um um_conv um_part um_um) no-lock
    where um_domain = vp_domain 
      and um_um     = vp_fromUm 
      and um_alt_um = vp_toUm
      and um_part   = vp_part:
  end.

  if available um_mstr then
    vl_result = if not vp_reverse then um_conv else (1 / um_conv).
  
  return vl_result.
  
END FUNCTION.

FUNCTION convertAmount RETURNS DECIMAL
  (vp_domain as char, vp_toUm as char, vp_fromUm as char, vp_part as char, vp_amount as dec):
  
  def var vl_result as dec no-undo.
  def var vl_conv   as dec no-undo init ?.
  
  if (vp_toUm <> vp_fromUm) then
  do:
    vl_conv = getConversionFactor(vp_domain, vp_toUm, vp_fromUm, vp_part, false).
    if vl_conv = ? then
      vl_conv = getConversionFactor(vp_domain, vp_fromUm, vp_toUm, vp_part, true).
    if vl_conv = ? then
      vl_conv = getConversionFactor(vp_domain, vp_toUm, vp_fromUm, "", false).
    if vl_conv = ? then
      vl_conv = getConversionFactor(vp_domain, vp_fromUm, vp_toUm, "", true).
  end.
  if vl_conv = ? then vl_conv = 1.
  
  vl_result = vp_amount * vl_conv.
  
  return vl_result.
  
END FUNCTION.