
/***
* Program     : xxcallws.p
* Description : This program calls the generic program to send the messages 
*               using Progress WebServices
* Date        : 01/03/2012
* By          : Bandula Abeysinge
* Change Log  :
* Date     By       Id     Desc
* -------- -------- ------ ----------------------------------------------------
* 01/03/12 babeysin BA00   Initital version
* 04/10/12 babeysin BA01   Use memory pointers instead of handles 
* 28/11/12 babeysin BA02   Check for the Send Flag
* 08/01/13 babeysin BA03   Changed the count only for WSDocs
* 30/04/13 babeysin BA04   Chaneg the scope of the standard table record
****/

def var vDocGroup as char format "x(40)" label "Document Group" no-undo.
def var vDocType  as char no-undo.
def var vStatus as integer no-undo.
def var vPause as int no-undo initial 0.
def var vOffLineDocs as char no-undo.
def var vDocsList as char no-undo.
def var vOffLineGroupList as char no-undo.
def var vOnLine as logical no-undo.
def var vCnt as int no-undo.
def var vOldValue as char no-undo.  /*BA02*/

/*BA01
def var hDocReq as handle no-undo.
def var hDocRes as handle no-undo.
*/
def var mDocReq as memptr no-undo.
def var mDocRes as memptr no-undo.
def var vRecId  as recid  no-undo. /*BA04*/

/*BA01
create x-document hDocReq. /* Document to handle the Request  */
create x-document hDocRes. /* Document to handle the Response */
*/

{mfdeclre.i}
{xxwsfunctions.i new}        /* Define functions and procedures */

update vDocGroup. 

/*--- Get the list of docs belong to this group ---*/
for each stdd_det where stdd_domain  = global_domain and stdd_code = "WSDocs"
    and stdd_subcode <> "OffLineGroupList"
    and entry(1, stdd_txtvalue) = vDocGroup
    /*BA02 - Check for message in the stagging table */
    and can-find(first sbt_det where sbt_domain = stdd_domain
        and sbt_doc_type = stdd_subcode)
    
    no-lock:
    vDocsList = vDocsList + (if vDocsList = "" then "" else ",")
                + stdd_subcode.
    /*BA03
    select sbt_doc_group format "x(25)", sbt_doc_type format "x(25)" , count(*)
    from sbt_det
    where sbt_domain = global_domain
        and sbt_doc_type = stdd_subcode
    group by sbt_doc_group, sbt_doc_type.
    */
    /*BA04
    select
        aa.stdd_domain, 
        entry(1, aa.stdd_txtvalue) format "x(25)" label "Group", 
        sbt_doc_type format "x(25)" , count(*)
    from sbt_det, stdd_det aa
    where sbt_domain = global_domain
        and sbt_doc_type = stdd_det.stdd_subcode
        and aa.stdd_domain = sbt_domain 
        and aa.stdd_code = "WSDocs" 
        and aa.stdd_subcode = sbt_doc_type
    group by entry(1, aa.stdd_txtvalue), sbt_doc_type.
    */
    
    vCnt = 0.
    for each sbt_det where sbt_domain = stdd_domain 
        and sbt_doc_type = stdd_subcode
        no-lock:
        vCnt = vCnt + 1.
    end.
    if vCnt > 0 then
        display 
            stdd_domain format "x(4)" label "Dom" 
            entry(1, stdd_txtvalue) format "x(13)" label "Group" 
            stdd_subcode format "x(22)" 
            vCnt format ">>>,>>9" label "count"        
            entry(3, stdd_txtvalue) format "x(10)" label "Status"
            entry(5, stdd_txtvalue) format "x(7)"  label "Rec/Msg"
            (if num-entries(stdd_txtvalue) >= 9 then    /*BA01*/
                entry(9, stdd_txtvalue) 
                else "")
                format "x(5)" label "Pause"
            replace((if num-entries(stdd_txtvalue) >= 10 then    /*BA01*/
                entry(10, stdd_txtvalue) 
                else "")
                ,"_","")
                format "x(3)" label "Env"
            .
end.

repeat vCnt = 1 to num-entries(vDocsList):
    vDocType = entry(vCnt, vDocsList).
    if not fOkToSend(vDocType, "On,OnLine,Send") then
    do:
        {mfmsg03.i 9104 2 vDocType "'WSDocs'" "'as On,OnLine,Send'"}
        next.
    end.
    hide message.    
    /*BA01
    {gprun.i ""xxsend2ws.p"" "(vDocType, hDocReq, output hDocRes)"}.
    */
    
    /* BA02 - Lock the DocType for this session */
    for first stdd_Det
        where stdd_domain = global_domain and stdd_code = "WSDocs"
            and stdd_subcode = vDocType:
        vOldValue = entry(3, stdd_txtvalue).
        entry(3, stdd_txtvalue) = "SENDING".
    end.

    find current stdd_det share-lock no-wait no-error.
    if avail stdd_det and not locked(stdd_det) then
    do:
        /*BA04 - Keep the record ID*/
        vRecId = recid(stdd_det).
        release stdd_det.
        {gprun.i ""xxsend2ws.p"" "(vDocType, mDocReq, output mDocRes)"}.
        /* Release the Document Type */
        for first stdd_Det
            where recid(stdd_det) = vRecId:
            if entry(3, stdd_txtvalue) = "Sending" then
                entry(3, stdd_txtvalue) = vOldValue.
        end.
        release stdd_det.
    end.
end.

/* BA01 - Reset the Memory Pointers */
assign
    set-size(mDocReq) = 0
    set-size(mDocRes) = 0.

