/// *********************************************************************************************************************
// File:    MLP_Converter_0.01.lsl
// Author:  Seth Nygard sethnygard@gmail.com
// Date:    March 2015
// For use with the PARAMOUR MULTI-ANIMATION CONTROLLER (PMAC) v1.0
//
// This script will attempt to read the existing MLPV2 notecards, parse out the information needed, and
// create new notecards ready for the PMAC v1.0 controller script.  Brute force parsing and checking is done
// in most places to work around the limitations of the list functions and/or due to the variability in the
// MLP format.
//
// Note: This script is still experimental and may contain bugs.
//
// *****  Always work with a copy of the item(s) you  are converting  *****
//
// Provided under Creative Commons Attribution-Non-Commercial-ShareAlike 4.0 International license.
// Please be sure you read and adhere to the terms of this license: https://creativecommons.org/licenses/by-nc-sa/4.0/
// *********************************************************************************************************************

//******* These will be applied to ALL positions *******
vector   gv_BallUserPositionOffset =<0,0,0>;          //Value ADDED to each position vector found in the MLP position notecard
vector   gv_BallUserRotationOffset =<0,0,0>;          //Value ADDED to the rotation vector found in the MLP position notecard
//******* ALL positions will be checked agains this *******
float    gf_MaxDistance            =10;               //Max distance the pose can be moved from the object

//======================================================================================================================
// Below this section should not be modified unless you know OpenSim scripting well.
// If you break it, you get to fix it.
//======================================================================================================================
string   gs_Version                ="MLP->PMAC Conversion 1.02";
integer  gi_SaveLog                =1;               // If set to 0 the log notecard will not be written
integer  gi_OpMode                 =0;               // Chat verbosity; 0=summary only: BitMask: 1=errors, 2=warnings,4=info
list     gl_ConversionLog          =[];
list     gl_MLP_Poses              =[];              // Imported pose names from MLPV2 notecard
list     gl_MLP_PosePositions      =[];              // Imported positions from MLPV2 notecard
list     gl_MLP_PoseAnimations     =[];              // Imported pose animation names
list     gl_MLP_Groups             =[];              // Imported groups
list     gl_MLP_NotecardNames      =[];              // Names of notecards we found
list     gl_PMAC_NotecardNames     =[];              // Names of notecards we saved
list     gl_AnimationNames         =[];              // Names of animations we found
list     gl_OriginalScriptNames    =[];              // Names of scripts we found
list     gl_OriginalObjectNames    =[];              // Names of other objects we found
string   gs_NotecardName           ="";
string   gs_ConfigName             =".PMAC-CONFIG";  // Name configuration notecard
string   gs_DefaultGroup           ="";              // Name of the menu group we will set as the default for PMAC
string   gs_Param_Pre              ="";              // Return string used in parsing, data before start delimeter
string   gs_Param_Arg              ="";              // Return string used in parsing, data between delimeters
string   gs_Param_Post             ="";              // Return string used in parsing, data after stop delimeter
integer  gi_MLP_MaxBallUsers       =0;               // Maximum number of ball users found
integer  gi_TotalPoseCount         =0;
integer  gi_VerifyAnims            =0;
integer  gi_DialogHandle           =-1;
integer  gi_DialogChannel          =-137894;
key      gk_DialogUser;
integer  gi_ImportErrors           =0;
integer  gi_ImportWarnings         =0;
integer  gi_ExportErrors           =0;
integer  gi_ExportWarnings         =0;
//---------------------------- HELPER FUNCTIONS ----------------------------
integer IsFloat(string sFloat) {
   integer iDecCount=0;
   integer iSignCount=0;
   integer i;
   for(i=0;i<llStringLength(sFloat);i++) {
      string sChar=llGetSubString(sFloat,i,i);
      if (llListFindList(["-",".","0","1","2","3","4","5","6","7","8","9"],(list)sChar)==-1) { return FALSE; }
      if (sChar==".") { iDecCount++; }
      if (sChar=="-") { iSignCount++; }
      if ((iDecCount>1) || (iSignCount>1)) { return FALSE; }
   }
   return TRUE;
}


integer IsVector(string sVector) {
   if (ParseAttrubute(sVector,0,"<",">",1,1)>0) {
      if (ParseAttrubute(gs_Param_Arg,0,",",",",1,1)>0) {
         return (IsFloat(gs_Param_Pre) && IsFloat(gs_Param_Arg) && IsFloat(gs_Param_Post));
      }
   }
   return FALSE;
}


//We use only text that preceeds a comment, everything else is discarded
string StripComment(string sSrc) {
   integer iPos=llSubStringIndex(sSrc,"//");
   if (llStringLength(sSrc)>0) {
      if (iPos==-1) {  //No comment found
         return llStringTrim(sSrc,STRING_TRIM);
      }else if (iPos>0) {  //Line has a comment beyond the start position
         return llStringTrim(llGetSubString(sSrc,0,iPos-1),STRING_TRIM);
      }
   }
   return "";  //We found an empty string or a command as the start so we don't use anything
}


string StripTrailingZeros(string sSrc) {
   integer iPos=llSubStringIndex(sSrc,".")+1;  //remove +1 if you don't want 1 zero kept
   integer iLen=llStringLength(sSrc);
   integer i;
   for(i=iLen-1;i>iPos;i--) {
      if ((integer)llGetSubString(sSrc,i,i+1)>0) { return llGetSubString(sSrc,0,i); }
   }
   return llGetSubString(sSrc,0,i);
}


// Function to scan left to right and extract first occurance of argument encapsulated by delimiters
// sSrc          - Source string to parse
// iStartPos     - Char position to start looking for Delimiter, 0=first char
// sDelimStart   - Delimiter of beginning of parameter, ""=No delimiter
// sDelimStop    - Delimiter of end of parameter, ""=No delimiter
// iDiscardDelim - Do we discard delimiters, 0=no, 1=yes
// iStripArgSpaces  - Do we strip embedded spaces from argument(not pre and post), 0=no, 1=yes
// ReturnValue   - size of argument found, not including delimeters
//  Function allows checking for either/both start and end delimiter from a position in the string and provides 4 return values
//     return - length of the argument found  (see gs_Param_Arg), + the following 3 global vars (more efficient than a list return)
//     gs_Param_Pre - portion of string found between the StartPos and the StartDelim
//     gs_Param_Arg - portion of string found between the StartDelim and StopDelim (may include delimiters)
//     gs_Param_Post - portion of string found after the StopDelim
//  Note: All Params are stripped of leading and training spaces, even if space was a delimter to be kept.
integer ParseAttrubute(string sSrc, integer iStartPos, string sDelimStart, string sDelimStop, integer iDiscardDelim, integer iStripArgSpaces) {
   integer iPos;
   gs_Param_Pre="";
   gs_Param_Arg="";
   gs_Param_Post="";
   if (iStartPos>0) { sSrc=llDeleteSubString(sSrc,0,iStartPos); }  //Get rid of anything we don't use
   if (sDelimStart=="") {
      iPos=0;
   }else{
      iPos=llSubStringIndex(sSrc,sDelimStart);  //Position of first char of delimiter (ok with no delimiter)
      if (iPos==-1) {
         gs_Param_Pre=llStringTrim(sSrc,STRING_TRIM);
         return(0);
      }else if (iPos>=0) {
         gs_Param_Pre=llGetSubString(sSrc,0,iPos-1);
      }
      iPos+=llStringLength(sDelimStart);
      if (iPos>0) {
         sSrc=llGetSubString(sSrc,iPos,llStringLength(sSrc));
      }
   }
   if (sDelimStop=="") {  //We have no stop delimiter so we return the argument
      gs_Param_Arg=sSrc;
   }else{
      iPos=llSubStringIndex(sSrc,sDelimStop);
      if (iPos==-1) {
         gs_Param_Arg=sSrc;
      }else if (iPos>0) {
         iPos+=llStringLength(sDelimStop);
         gs_Param_Post=llGetSubString(sSrc,iPos,llStringLength(sSrc));
         iPos-=(llStringLength(sDelimStop)+1);
         if (iPos>=0) {
            gs_Param_Arg=llGetSubString(sSrc,0,iPos);
            if (iDiscardDelim==0) { gs_Param_Arg=sDelimStart+gs_Param_Arg+sDelimStop; }
         }
      }else{
         gs_Param_Arg=sSrc;
         if (iDiscardDelim==0) { gs_Param_Arg=sDelimStart+gs_Param_Arg; }
      }
   }
   if (iStripArgSpaces) { gs_Param_Arg=osReplaceString(gs_Param_Arg," ","",-1,0); }
   gs_Param_Pre=llStringTrim(gs_Param_Pre,STRING_TRIM);
   gs_Param_Arg=llStringTrim(gs_Param_Arg,STRING_TRIM);
   gs_Param_Post=llStringTrim(gs_Param_Post,STRING_TRIM);
   return(llStringLength(gs_Param_Arg));
}


StopAnyExistingScripts() {
   string sName;
   integer i;
   for(i=0;i<llGetInventoryNumber(INVENTORY_SCRIPT);i++) {
      sName=llGetInventoryName(INVENTORY_SCRIPT, i);
      if (sName!=llGetScriptName()) {
         gl_OriginalScriptNames+=[sName];
         if (llGetScriptState(sName)==TRUE) {
            AddLog("Info","Startup","Found pre-existing script: "+sName+", stopped execution.",0);
            llSetScriptState(sName,0);
         }else{
            AddLog("Info","Startup","Found pre-existing script: "+sName+", not running.",0);
         }
      }
   }
   AddLog("Info","Startup","Stopped "+(string)(i-1)+" pre-existing scripts found.",1);
}


AddLog(string sType, string sStep, string sMsg, integer iShow) {
   string sTxt=sType+":"+sStep+":"+sMsg;
   if (sType=="Error") {
      if (sStep=="Import") {
         ++gi_ImportErrors;
      }else if (sStep=="Export") {
         ++gi_ExportErrors;
      }
      if ((gi_OpMode & 1)==1) { iShow=1; }
   }else if (sType=="Warn") {
      if (sStep=="Import") {
         ++gi_ImportWarnings;
      }else if (sStep=="Export") {
         ++gi_ExportWarnings;
      }else if (sType=="Info") {
         if ((gi_OpMode & 2)==2) { iShow=1; }
      }
   }
   if ((gi_OpMode & 4)==4) { iShow=1; }
   if (iShow==1) { llOwnerSay("Log: "+sTxt); }
   gl_ConversionLog+=[sTxt];
}


//**************************** TASK FUNCTIONS ****************************
ImportPosePositions(string sNotecardName) {
   // Since the original notecard may be inconsistent and lacks unique markers we will scan it brute force
   // Line Format: {PoseName} <VectorPosUser0> <RotationUser0> ... <VectorPosUserN> <RotationUserN>
   // Note: PoseName may contain spaces, spaces are the delimeter and may also ocurr anywhere else on each line

   integer i;
   string sLine;
   string sPose;
   string sArgs;
   integer iNumSkipped=0;
   integer iNumPoses=0;
   integer iErr;
   for(i=0;i<osGetNumberOfNotecardLines(sNotecardName); i++) {
      sLine=StripComment(osGetNotecardLine(sNotecardName,i));
      if (ParseAttrubute(sLine,0,"{","}",1,0)>0) {
         if (~llListFindList(gl_MLP_PosePositions,(list)gs_Param_Arg)) {
            AddLog("Warn","Import","Duplicate Pose found, skipping.",0);
            iNumSkipped++;
         }else{
            sPose=gs_Param_Arg;
            sArgs="";
            iErr=0;
            // We found a PoseName, so lets keep going
            integer iNumVectorsFound=0;
            string sParams=gs_Param_Post;
            while(ParseAttrubute(sParams,0,"<",">",0,1)>0) {
               sParams=gs_Param_Post;
               string sStash=gs_Param_Arg;
               if (IsVector(sStash)==TRUE) {
                  string sParam;
                  vector vTemp=(vector)sStash;
                  if ((iNumVectorsFound&0x01)==0) {
                     vTemp+=gv_BallUserPositionOffset;
                     if ((vTemp.x*vTemp.x + vTemp.y*vTemp.y + vTemp.z*vTemp.z)<=(gf_MaxDistance*gf_MaxDistance)) {
                        sParam=(string)(vTemp);
                     }else{
                        AddLog("Warn","Import","Vector out of range in pose'"+sPose+"' at line number "+(string)i+", Changed to <0,0,0>.",0);
                        vTemp=ZERO_VECTOR;
                     }
                  }else{
                     sParam=(string)llEuler2Rot((vector)(vTemp+gv_BallUserRotationOffset)*DEG_TO_RAD);
                  }
                  if (ParseAttrubute(sParam,0,"<",">",1,1)>0) {
                     sParam="<";
                     gs_Param_Post=gs_Param_Arg;
                     integer iP=0;
                     while(ParseAttrubute(gs_Param_Post,0,"",",",1,0)>0) {
                        if (iP++!=0) { sParam+=","; }
                        sParam+=StripTrailingZeros(gs_Param_Arg);
                     }
                     sParam+=">";
                     sArgs+="|"+sParam;
                     iNumVectorsFound++;
                  }else{
                     iErr++;
                  }
               }else{
                  iErr++;
               }
            }//Continue to the end of the line
            if (iErr==0) {
               if ((iNumVectorsFound&0x01)==0) {
                  gl_MLP_Poses+=[sPose];
                  gl_MLP_PosePositions+=[sArgs];
                  iNumPoses++;
               }else{
                  AddLog("Error","Import","Found a missing vector at line "+(string)i+" in notecard "+sNotecardName+".  Position was skipped.",0);
               }
            }else{
               AddLog("Error","Import","Found a bad vector at line "+(string)i+" in notecard "+sNotecardName+".  Position was skipped.",0);
            }
         }
      }
   }
   if (iNumSkipped>0) { AddLog("Warn","Import","Skipped "+(string)iNumSkipped+" duplicate pose names.",0); }
   AddLog("Info","Import","Total "+(string)llGetListLength(gl_MLP_PosePositions)+" pose entries found.",0);
}


ImportMenuParams(string sNotecardName ) {
   // Since the original notecard may be inconsistent and lacks unique markers we will scan it brute force
   // We currently parse out MENU and POSE lines
   // POSE entries are added the the preceeding group as found from MENU entries
   integer i;
   string sLine="";
   string sArgs="";
   string sCurrentMenu="DefaultMLP";
   string sCurrentMenuUser="ALL";
   string sNewMenu="";
   string sNewMenuUser="";
   list lParams=[];
   list lGroupPoses=[];
   integer iPoseCount=0;
   for(i=0;i<osGetNumberOfNotecardLines(sNotecardName); i++) {
      sLine=StripComment(osGetNotecardLine(sNotecardName,i));
      if (ParseAttrubute(sLine,0,""," ",1,0)>0) {
         if (gs_Param_Arg == "MENU" ) {
            lParams=llParseString2List(gs_Param_Post,["|"," | "],"");
            if (llGetListLength(lParams)>1) {
               sNewMenu=llStringTrim(llList2String(lParams,0),STRING_TRIM);
               sNewMenuUser=llStringTrim(llList2String(lParams,1),STRING_TRIM);
               integer iG=llGetListLength(lParams)-2;
               if (iG>gi_MLP_MaxBallUsers) { gi_MLP_MaxBallUsers=iG; }
               if ((sNewMenu!=sCurrentMenu) && (iPoseCount>0) ) {
                  // We may have a new group so stash any group poses we have accumulated
                  if (sCurrentMenu!="DefaultMLP")
                     StashGroupPoses(sCurrentMenu+":"+sCurrentMenuUser,lGroupPoses);
                  sCurrentMenu=sNewMenu;
                  sCurrentMenuUser=sNewMenuUser;
                  iPoseCount=0;
                  lGroupPoses=[];
               }else{
                  sCurrentMenu=sNewMenu;
                  sCurrentMenuUser=sNewMenuUser;
               }
            }
         }else if (gs_Param_Arg == "POSE" ) {
            lParams=llParseString2List(gs_Param_Post,["|"," | "],"");
            integer iNumParams=llGetListLength(lParams);
            integer iP;
            string sParams="";
            string sPoseName="";
            string sAnimName="";
            integer iSkip=0;
            for(iP=0;iP<iNumParams;iP++) {
               string sP=llStringTrim(llList2String(lParams,iP),STRING_TRIM);
               if (iP==0) {
                  sPoseName=llStringTrim(sP,STRING_TRIM);
               }else{
                  sParams+="|";
               }
               if (ParseAttrubute(sP,0,"::"," ",0,0)>0) {
                  sParams+=osReplaceString(gs_Param_Pre+gs_Param_Arg, ",", ".",-1,0);
                  sAnimName=gs_Param_Pre;
               }else{
                  sParams+=sP;
                  sAnimName=sP;
               }
               if ((iP>0) && (gi_VerifyAnims==1) && (llListFindList(gl_AnimationNames,(list)sAnimName)==-1) && (sCurrentMenu!="DefaultMLP")) {
                  iSkip=1;
                  AddLog("Error","Import","Unable to find a matching animation: '"+sAnimName+"' at line "+(string)i+" in notecard: '"+sNotecardName+"'.  Pose skipped.",0);
               }
            }
            if ((iNumParams>0) && (iSkip==0)) {
               if (llListFindList(gl_MLP_Poses,(list)sPoseName)!=-1) {
                  lGroupPoses+=sParams+"|";
                  iPoseCount++;
               }else{
                  AddLog("Error","Import","Unable to find a matching position for pose: '"+sPoseName+"' at line "+(string)i+" in notecard: '"+sNotecardName+"'.  Pose skipped.",0);
               }
            }
         }
      }
   }
   if (iPoseCount>0 ) {
      if (sCurrentMenu!="DefaultMLP") StashGroupPoses(sCurrentMenu+":"+sCurrentMenuUser,lGroupPoses);
      gi_TotalPoseCount+=iPoseCount;
   }
}


StashGroupPoses(string sGroupName,list lPoses) {
   gl_MLP_Groups+=[sGroupName];
   gl_MLP_PoseAnimations+=[llDumpList2String(lPoses,"||")];
}


GetMLPNotecards() {
   string sName;
   integer i;
   list lMenuitemNotecards=[];
   list lPositionNotecards=[];
   gi_TotalPoseCount=0;
   gl_MLP_PosePositions=[];
   gl_MLP_Groups=[];
   integer iNumMLPNotecards=llGetInventoryNumber(INVENTORY_NOTECARD);
   for(i=0;i<iNumMLPNotecards;i++) {
      sName=llGetInventoryName(INVENTORY_NOTECARD, i);
      if (llSubStringIndex(sName,".POSITIONS")!=-1) {  //We can have multiple files
         if (llGetInventoryKey(sName)) {
            lPositionNotecards+=[sName];
         }else{
            AddLog("Error","Import","Notecard '"+sName+"' has no matching key.  Skipped.",0);
         }
      } else if (llSubStringIndex(sName,".MENUITEM")!=-1) {  //We can have multiple files
         if (llGetInventoryKey(sName)) {
            lMenuitemNotecards+=[sName];
         }else{
            AddLog("Error","Import","Notecard '"+sName+"' has no matching key.  Skipped.",0);
         }
      }else{
         AddLog("Info","Import","Skipping unhandled notecard: "+sName,0);
      }
   }
   lPositionNotecards=llListSort(lPositionNotecards,1,TRUE);  //Sort the list since we handle top POSITIONS first
   for(i=0;i<llGetListLength(lPositionNotecards);i++) {
      sName=llList2String(lPositionNotecards,i);
      AddLog("Info","Import","Parsing Pose Posistions from "+sName+" ...",0);
      ImportPosePositions(sName);
      gl_MLP_NotecardNames+=[sName];
   }

   lMenuitemNotecards=llListSort(lMenuitemNotecards,1,TRUE);  //Sort the list since we handle top MENUITEM first
   for(i=0;i<llGetListLength(lMenuitemNotecards);i++) {
      sName=llList2String(lMenuitemNotecards,i);
      AddLog("Info","Import","Parsing Menu items from "+sName+" ...",0);
      ImportMenuParams(sName);
      gl_MLP_NotecardNames+=[sName];
   }
}


ExportMenuCards(integer iOKToSave) {
   //Name Format: .menuSSNP Name
   //                   |||| +--- Menu Group Name
   //                   |||+----- Space separator (1 fixed char)
   //                   ||+------ Permissions(A=all,G=Group,O=Owner) (1 fixed char)
   //                   |+------- Number of positions (1 numeric char)
   //                   +-------- Sort order (2 alpha chars)
   // Example: .menu012A Couples = menu, 01 sort order, 2 positions, All users, Couples menu

   integer iNumGroups=llGetListLength(gl_MLP_Groups);
   integer iNumGroupPoses=llGetListLength(gl_MLP_PoseAnimations);
   integer iG;
   integer iP;
   list lNotecard=[];
   string gs_DefaultGroup="";

   for(iG=0;iG<iNumGroups;iG++) {
      lNotecard=[];
      integer iErr=0;
      integer iNumBallUsers=0;
      list lPose=llParseString2List(llList2String(gl_MLP_PoseAnimations,iG),"||","");
      for(iP=0;iP<llGetListLength(lPose);iP++) {
         integer iLErr=0;
         list lPoseParams=llParseString2List(llList2String(lPose,iP),"|","");
         string sPoseName=llStringTrim(llList2String(lPoseParams,0),STRING_TRIM);
         integer iPositionIndex=llListFindList(gl_MLP_Poses,(list)sPoseName);
         if (iPositionIndex==-1) {
            AddLog("Warn","Export","Unable to find matching positions for "+sPoseName+", skipped.",0);
            iErr++;
         }else{
            string sLine="";
            string sCom="NO COM";
            list lExpress=[];
            integer iSkip=0;
            integer iHaveExpressions=0;
            list lPositions=llParseString2List(llList2String(gl_MLP_PosePositions,iPositionIndex),"|","");
            integer iNumBalls=llGetListLength(lPoseParams)-1;
            if (iNumBallUsers==0) iNumBallUsers=iNumBalls;  //All subsequent NumBalls must be the same in this Group
            integer iNumPositions=llGetListLength(lPositions);
            if (iNumPositions!=(2*iNumBallUsers)) {
               AddLog("Error","Export","Mismatched animations and positions for "+sPoseName+", skipped.",0);
               iErr++;
            }else if (iNumBallUsers != iNumBalls) {
               AddLog("Error","Export","Mismatched number of ball users in group "+sPoseName+", skipped.",0);
               iErr++;
            }else{
               integer iB;
               for(iB=0;iB<iNumBalls;iB++) {
                  string sAnim=llList2String(lPoseParams,iB+1);
                  string sE="0";
                  string sT="0";
                  if (ParseAttrubute(sAnim,0,"::"," ",0,0)>0) {
                     iHaveExpressions=1;
                     sAnim=gs_Param_Pre;
                     sE=gs_Param_Arg;
                     if (ParseAttrubute(sE,0,"::","::",1,0)>0) {
                        sE=gs_Param_Pre;
                        sT=gs_Param_Arg;
                     }
                  }
                  sAnim=llStringTrim(sAnim,STRING_TRIM);
                  if ((gi_VerifyAnims==0) || (llListFindList(gl_AnimationNames,(list)sAnim)!=-1)) {
                     sLine+="|"+sAnim+"|"+llList2String(lPositions,iB<<1)+"|"+llList2String(lPositions,(iB<<1)+1);
                     lExpress+=[sE,sT];
                  }else{
                     AddLog("Error","Export","Unable to find animation with name '"+sAnim+"', skipped.",0);
                     iSkip++;
                  }
               }
               if (iSkip==0) {
                  if (iHaveExpressions) sCom="PAO_EXPRESS{"+llDumpList2String(lExpress,"::")+"}";
                  lNotecard+=[sPoseName+"|"+sCom+sLine];
               }else{
                  iErr++;
               }
            }
         }
      }
      if (llGetListLength(lNotecard)>0) {
         string sSort=(string)iG;
         integer iS;
         string sGroupPerm;
         for(iS=llStringLength(sSort);iS<2;iS++) { sSort="0"+sSort; }
         list lGroupParams=llParseString2List(llList2String(gl_MLP_Groups,iG),":","");
         string sG=llList2String(lGroupParams,1);
         if (sG=="GROUP") {
            sGroupPerm="G";
         }else if (sG=="OWNER") {
            sGroupPerm="O";
         }else{
            sGroupPerm="A";
         }
         list lParams=[sSort,(string)iNumBallUsers,sGroupPerm,llList2String(lGroupParams,0)];
         string sMenuNotecardName=osFormatString(".menu{0}{1}{2} {3}",lParams);
         gl_PMAC_NotecardNames+=[sMenuNotecardName];
         if (iErr==0) {
            if (gs_DefaultGroup=="") {
               gs_DefaultGroup=sG;
               AddLog("Info","Export","Selecting default menu group : "+gs_DefaultGroup,0);
            }
            if (iOKToSave) {
               AddLog("Info","Export","Saving Notecard: "+sMenuNotecardName,0);
               osMakeNotecard(sMenuNotecardName,lNotecard);
            }
         }else{
            AddLog("Info","Export","Total number of errors found during PMAC notecard export: "+(string)iErr,0);
         }
      }
   }
   llOwnerSay("Exported "+(string)iG+" menu groups.");
   ParseAttrubute(llList2String(gl_MLP_Groups,0),0,"",":",1,0);
   lNotecard=["DefaultGroup="+gs_Param_Arg];
   lNotecard+=["ResetOnQuit=TRUE"];
   if (iOKToSave==1) {
      osMakeNotecard(gs_ConfigName,llDumpList2String(lNotecard,"\n"));
      AddLog("Info","Export","Saved PMAC configuration file "+gs_ConfigName,0);
   }
}


GetAnimationAndObjectNames() {
   integer iNumAssets=llGetInventoryNumber(INVENTORY_ANIMATION);
   string sName="";
   integer i;
   gl_AnimationNames=[];
   for(i=0;i<iNumAssets;i++) {
      sName=llGetInventoryName(INVENTORY_ANIMATION, i);
      if (llGetInventoryKey(sName)) {
         gl_AnimationNames+=[sName];
      }else{
         AddLog("Error","Init","Animation '"+sName+"' has no matching key, skipped.",0);
      }
   }
   i=llGetListLength(gl_AnimationNames);
   gi_VerifyAnims=(i>0);
   AddLog("Info","Init","Found "+(string)i+" animations.",0);

   iNumAssets=llGetInventoryNumber(INVENTORY_OBJECT);
   gl_OriginalObjectNames=[];
   for(i=0;i<iNumAssets;i++) {
      sName=llGetInventoryName(INVENTORY_OBJECT, i);
      if (llGetInventoryKey(sName)) {
         gl_OriginalObjectNames+=[sName];
      }else{
         AddLog("Error","Init","Object '"+sName+"' has no matching key, skipped.",0);
      }
   }
   AddLog("Info","Init","Found "+(string)llGetListLength(gl_OriginalObjectNames)+" inventory objects.",0);
}


ShowStatus(integer iLog) {
   string sTxt="   Animations found: "+(string)llGetListLength(gl_AnimationNames);
   if (gi_VerifyAnims==0) { sTxt+=" ** No verfication of animations will be done. **"; }
   sTxt+="\n   MLP Menu Groups found: "+(string)llGetListLength(gl_MLP_Groups);
   sTxt+="\n   MLP Poses found: "+(string)llGetListLength(gl_MLP_Poses);
   sTxt+="\n   MLP Max Ball Users found: "+(string)gi_MLP_MaxBallUsers;
   sTxt+="\n   MLP Pose Positions found: "+(string)llGetListLength(gl_MLP_PosePositions);
   sTxt+="\n   MLP Pose Positions adjusted using;";
   sTxt+="\n       PosOffset="+(string)gv_BallUserPositionOffset;
   sTxt+="\n       RotOffset="+(string)gv_BallUserRotationOffset;
   if ((gi_ImportErrors==0) && (gi_ImportWarnings==0)) {
      sTxt+="\n   No Import errors or warnings found.";
   }else{
      if (gi_ImportErrors>0) {
         sTxt+="\n   *** Import Errors: "+(string)gi_ImportErrors+" ***";
      }
      if (gi_ImportWarnings>0) {
         sTxt+="\n   *** Import Warnings: "+(string)gi_ImportWarnings+" ***";
      }
   }
   if (iLog==1) {
      AddLog("Info","Import","Summary:\n"+sTxt,1);
   }else{
      llOwnerSay("Import Summary:\n"+sTxt);
   }
}


AddDialog() {
   list gl_DialogButtons;
   string sDialogInfo="MLP->PMAC Converter (120 Sec Timeout.)";
   sDialogInfo+="\n\nConvert - save into PMAC format";
   sDialogInfo+="\nShow Log - dump import log to chat.";
   sDialogInfo+="\nCancel - Don't save or delete anything";
   gl_DialogButtons=["Convert","Show Log","Cancel"];
   gk_DialogUser=llGetOwner();
   llListenRemove(gi_DialogHandle);
   gi_DialogHandle=llListen(gi_DialogChannel,"",gk_DialogUser,"");
   llDialog(gk_DialogUser,sDialogInfo,gl_DialogButtons,gi_DialogChannel);
   llSetTimerEvent(120);
}


ImportMLP() {
   gl_MLP_PosePositions=[];
   gl_MLP_PoseAnimations=[];
   gl_MLP_Groups=[];
   gl_MLP_Poses=[];
   gi_MLP_MaxBallUsers=0;
   gl_MLP_NotecardNames=[];
   gl_PMAC_NotecardNames=[];
   gi_ImportErrors=0;
   gi_ImportWarnings=0;
   gi_ExportErrors=0;
   gi_ExportWarnings=0;
   llResetTime();
   GetAnimationAndObjectNames();
   GetMLPNotecards();
   AddLog("Info","Import","Elapsed time to load MLP notecards: "+(string)llGetTime()+" seconds.",0);
   ShowStatus(1);
}


RemoveMLP() {
   integer i;
   string sName;
   for(i=0;i<llGetListLength(gl_MLP_NotecardNames);i++) {
      sName=llList2String(gl_MLP_NotecardNames,i);
         AddLog("Info","Cleanup","Removing MLP Notecard "+sName,0);
         llRemoveInventory(sName);
   }
   for(i=0;i<llGetListLength(gl_OriginalScriptNames);i++) {
      sName=llList2String(gl_OriginalScriptNames,i);
      AddLog("Info","Cleanup","Removing old script "+sName,0);
      llRemoveInventory(sName);
   }
   integer iRemove=0;
   for(i=0;i<llGetListLength(gl_OriginalObjectNames);i++) {
      sName=llList2String(gl_OriginalObjectNames,i);
      iRemove=0;
      if (llGetSubString(sName,0,5)=="~ball") { iRemove=1; }
      if (llGetSubString(sName,0,13)=="~~~positioner") { iRemove=1; }
      if (iRemove==0) {
         AddLog("Info","Cleanup","Leaving inventory object "+sName+".  This may be user removed if no longer needed",0);
      }else{
         AddLog("Info","Cleanup","Removing inventory object "+sName,0);
         llRemoveInventory(sName);
      }
   }
}


SavePMAC() {
   llResetTime();
   ExportMenuCards(TRUE);
   AddLog("Info","Export","PMAC Save:Elapsed time to export PMAC Notecards: "+(string)llGetTime()+" seconds.",0);
}


RemovePMAC() {
   integer i;
   string sNName;
   for(i=0;i<llGetListLength(gl_PMAC_NotecardNames);i++) {
      sNName=llList2String(gl_PMAC_NotecardNames,i);
      AddLog("Info","Cancel Export","Removing PMAC Notecard "+sNName,0);
      llRemoveInventory(sNName);
   }
   AddLog("Info","Cancel Export","Removing PMAC Configuration file "+gs_ConfigName,0);
   llRemoveInventory(gs_ConfigName);
   gl_PMAC_NotecardNames=[];
   gi_TotalPoseCount=0;
}


SaveLog() {
   if (gi_SaveLog==1) {
      AddLog("Info","Done","Save log "+osUnixTimeToTimestamp((integer)llGetUnixTime()),0);
      llOwnerSay("Conversion log can be found in the notecard: .LOG-MLP-to-PMAC*");
      osMakeNotecard(".LOG-MLP-to-PMAC", gl_ConversionLog);
      gl_ConversionLog=[gs_Version];
   }
}


DoneAndRemoveMe() {
   SaveLog();
   llSitTarget(ZERO_VECTOR,ZERO_ROTATION);
   llSetClickAction(CLICK_ACTION_SIT);
   llOwnerSay("Done. You may now copy the Paramour Multi-Animation Controller into the object.");
   llRemoveInventory(llGetScriptName());
}


default {
   state_entry() {
      if (llGetAttached()==0) {
         if (llGetLinkNumber()>1) {
            llOwnerSay("ERROR! This script must always be located in the root prim of a linkset!\nScript has been removed.");
            llRemoveInventory(llGetScriptName());
         }else{
            gi_DialogChannel=0x80000000 | (integer)("0x"+(string)llGetKey());
            gl_ConversionLog=[gs_Version];
            AddLog("Info","Startup","Initialized. "+osUnixTimeToTimestamp((integer)llGetUnixTime()),0);
            llOwnerSay("MLP to PMAC Converter.   Stopping any existing scripts...");
            StopAnyExistingScripts();
            llSetClickAction(CLICK_ACTION_TOUCH);
            llOwnerSay("\nNote: **** This script is experimental. ****\nIf you break things you get to keep all the parts.\n**** Always work with copy of the object being converted. ****\n\nTouch to start.");
         }
      }else{
         return;
      }
   }

   on_rez(integer iNum) {
      llResetScript();
   }

   touch_start(integer iNum) {
      if (llGetAttached()==0) {
         if (llDetectedKey(0)==llGetOwner()) {
            AddLog("Info","User","Touched to start: "+osUnixTimeToTimestamp((integer)llGetUnixTime()),0);
            llOwnerSay("Checking object for MLP notecards...");
            ImportMLP();
            if ( (llGetListLength(gl_MLP_Groups)==0) || (llGetListLength(gl_MLP_Poses)==0) || (gi_MLP_MaxBallUsers==0) || (llGetListLength(gl_MLP_PosePositions)==0)) {
               AddLog("Error","Import","Unable to find enough informaiton to convert.",1);
               SaveLog();
            }else{
               AddDialog();
            }
         }else{
            llSay(0,"Sorry.  The MLP converter can only be used by the owner of the object.");
         }
      }else{
         return;
      }
   }

   listen(integer iChannel, string sWho, key kID, string sMsg) {
      //["Convert","Cancel"];
      if (kID=gk_DialogUser) {
         if (sMsg=="Convert") {
            AddLog("Info","Dialog","Auto conversion started at "+osUnixTimeToTimestamp((integer)llGetUnixTime()),1);
            SavePMAC();
            string sTxt="Export Summary";
            if ((gi_ExportErrors==0) && (gi_ExportWarnings==0)) {
               sTxt+="\n   No Export errors or warnings found.";
            }else{
               if (gi_ExportErrors>0) {
                  sTxt+="\n*** Export Errors found: "+(string)gi_ExportErrors+" ***";
               }
               if (gi_ExportWarnings>0) {
                  sTxt+="\n*** Export Warnings found: "+(string)gi_ExportWarnings+" ***";
               }
            }
            AddLog("Info","Export",sTxt,1);
            llListenRemove(gi_DialogHandle);
            gi_DialogHandle=llListen(gi_DialogChannel,"",gk_DialogUser,"");
            string sDialogInfo="MLP->PMAC Converter (120 Sec Timeout.)";
            sDialogInfo+="\n\nAre you sure you want to delete all MLP notecards,objects,scripts?";
            sDialogInfo+="\nShow Log - dump import log to chat.";
            sDialogInfo+="\nAbort - Undo PMAC Notecards and abort MLP Cleanup";
            llDialog(gk_DialogUser,sDialogInfo,["YES-DELETE","Show Log","Abort"],gi_DialogChannel);
            llSetTimerEvent(120);
         }else if (sMsg=="YES-DELETE") {
            AddLog("Info","Dialog","Delete MLP items.",1);
            RemoveMLP();
            DoneAndRemoveMe();
         }else if (sMsg=="Show Log") {
            integer i;
            for(i=0;i<llGetListLength(gl_ConversionLog);i++) {
               llOwnerSay(llList2String(gl_ConversionLog,i));
            }
            AddDialog();
         }else if (sMsg=="Cancel") {
            llOwnerSay("Operation cancelled by user.");
            AddLog("Info","Dialog","Cancel by user: "+osUnixTimeToTimestamp((integer)llGetUnixTime()),1);
            SaveLog();
            //We don't do anything
            llListenRemove(gi_DialogHandle);
            llSetTimerEvent(0);
         }else if (sMsg=="Abort") {
            llOwnerSay("Operation cancelled by user.");
            AddLog("Info","Dialog","Cleanup Abort by user: "+osUnixTimeToTimestamp((integer)llGetUnixTime()),1);
            RemovePMAC();
            SaveLog();
            //We don't do anything
            llListenRemove(gi_DialogHandle);
            llSetTimerEvent(0);
         }else if (sMsg=="") {
            AddDialog();
         }else{
            llOwnerSay("Error.  Unhandled dialog command "+sMsg);
         }
      }else{
         llOwnerSay("Unexpected Msg received from key "+(string)kID);
      }
   }

   timer() {
      llSetTimerEvent(0);
      llListenRemove(gi_DialogHandle);
      gi_DialogHandle=-1;
      llOwnerSay("Timeout, User dialog menu has been dissabled.");
   }
}
