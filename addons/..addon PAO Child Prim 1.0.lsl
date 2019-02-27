// CHILD PRIM ADD-ON FOR PMAC 1.x
// by Aine Caoimhe (c. LACM) July 2015
// Provided under Creative Commons Attribution-Non-Commercial-ShareAlike 4.0 International license.
// Please be sure you read and adhere to the terms of this license: https://creativecommons.org/licenses/by-nc-sa/4.0/
//
// Command format for this addon:
// PAO_CHILD{name::change::arg1::arg2....}
// where for each child prim that you want to move you need to supply
//      name        the UNIQUE name of the child prim to be moved -- this CAN be the root prim for changing ALPHA but CAN NOT be the root prim if you want to move it
//      change      either SET_ALPHA or SET_POS (case sensitive) where:
//          IF change=SET_ALPHA:
//              arg1 = the integer value of the face to change (-1 = ALL_SIDES and must be supplied as the integer value...do no use the text string)
//              arg2 = the float alpha value to set
//          IF change=SET_POS:
//              arg1 = the vector relative position you want to move it to
//              arg2 = the quaternion relative rotation you want to move it to
// you can move multiple child prims by extending this list as long as you like...it will work its way through the list
// DO NOT include any extra spaces between the separators or before/after the curly braces
//
// * * * * * * * * * *
// USER VARIABLES
// * * * * * * * * * *
//
// When PMAC is in edit mode, when you click the "STORE ADDON" button data will be said to you (and only you) in local chat based on these settings
list childNamesOfInterest=[ // the (unique) names of any child prims that you want data to be given for...only prims listed here will be said to you
    // "childPrimName1", "childPrimName5", etc...
    ];
string dataToSay="BOTH_SIMPLE";
//      VALUES for dataToSay for each of the child prims named in childNamesOfInterest:
//              POS_ROT         = the current relative position followed by the current relative rotation of the child prim
//              ALPHA_0         = the current alpha value of face 0 of the child prim formatted to set the alpha value for all faces
//              ALPHA_ALL       = the current alpha value of each face of the child prim
//              BOTH_SIMPLE     = POS_ROT + ALPHA_0 of the child prim formatted to set the alpha value for all faces
//              BOTH_ALL        = POS_RPT + ALPHA_ALL of the child prim
//
// THIS SCRIPT ITSELF CAN BE CHANGED AND RESET DURING OPERATION WITHOUT ANY ISSUES BUT IF YOU CHANGE THE LINK ORDER OR A PRIM NAME YOU WILL NEED TO RESET THE SCRIPT
//
// * * * * * * * * * * * * * * * * * * * * * * ** * * * * * * * * * * *
// DON'T CHANGE ANYTHING BELOW HERE UNLESS YOU KNOW WHAT YOU'RE DOING
// * * * * * * * * * * * * * * * * * * * * * * ** * * * * * * * * * * *
list childList;
buildChildList()
{
    integer l=llGetNumberOfPrims();
    childList=[];
    
    while (l>0)
    {
        if (llGetAgentSize(llGetLinkKey(l))==ZERO_VECTOR) childList=[]+[llGetLinkName(l)]+childList;
        l--;
    }
    childList=[]+["CHILD LIST"]+childList;
}
default
{
    state_entry()
    {
        if (llGetLinkNumber()>1)
        {
            llOwnerSay("ERROR! PAO_CHILD script MUST be in the root prim of an object");
            return;
        }
        buildChildList();
    }
    link_message(integer sender, integer num, string message, key sitters)
    {
        list parsed=llParseString2List(message,["|"],[]);
        string command=llList2String(parsed,0);
        if (command=="GLOBAL_NEXT_AN")
        {
            list commandBlock=llParseString2List(llList2String(parsed,1),["{","}"],[]);
            integer myBlock=llListFindList(commandBlock,"PAO_CHILD");
            if (myBlock>=0)
            {
                list myData=llParseString2List(llList2String(commandBlock,myBlock+1),["::"],[]);
                integer i;
                integer l=llGetListLength(myData);
                while (i<l)
                {
                    string childName=llList2String(myData,i);
                    string change=llList2String(myData,i+1);
                    string arg1=llList2String(myData,i+2);
                    string arg2=llList2String(myData,i+3);
                    integer link=llListFindList(childList,[childName]);
                    if (link<1) llOwnerSay("ERROR! PAO_CHILD addon received a command for a prim with the name "+childName+" but no prim could be found with that name");
                    else
                    {
                        if (change=="POS_ROT")
                        {
                            if (link==1) llOwnerSay("ERROR! PAO_CHILD addon received a command to move the root prim. You cannot move the root prim with this add-on!");
                            else llSetLinkPrimitiveParams(link,[PRIM_POS_LOCAL,(vector)arg1,PRIM_ROT_LOCAL,(rotation)arg2]);
                        }
                        else if (change=="SET_ALPHA") llSetLinkAlpha(link,(float)arg2,(integer)arg1);
                        else llOwnerSay("ERROR! PAO_CHILD addon received a command with the change value "+change+". Valid changes are POS_ROT or SET_ALPHA");
                    }
                    i+=4;
                }
            }
        }
        else if (command=="GLOBAL_STORE_ADDON_NOTICE")
        {
            list strToSay;
            integer l;
            integer stop=llGetListLength(childNamesOfInterest);
            while (l<stop)
            {
                integer link=llListFindList(childList,[llList2String(childNamesOfInterest,l)]);
                if (link<1) llOwnerSay("ERROR! PAO_CHILD was give a child prim name of interest \""+llList2String(childNamesOfInterest,l)+"\" but no prim with that name was found. If you have renamed a prim you need to reset the add-on script to pick up that change");
                else
                {
                    list data;
                    if ((dataToSay=="POS_ROT") || (llSubStringIndex(dataToSay,"BOTH")==0))
                    {
                        data=[]+llGetLinkPrimitiveParams(link,[PRIM_POS_LOCAL,PRIM_ROT_LOCAL]);
                        if (link!=1) strToSay=[]+strToSay+[llList2String(childNamesOfInterest,l)+"::POS_ROT::"+llList2String(data,0)+"::"+llList2String(data,1)];
                    }
                    if ((llSubStringIndex(dataToSay,"ALPHA")==0) || (llSubStringIndex(dataToSay,"BOTH")==0))
                    {
                        integer f;
                        if ((dataToSay=="ALPHA_0")||(dataToSay=="BOTH_SIMPLE")) strToSay=[]+strToSay+[llList2String(childNamesOfInterest,l)+"::SET_ALPHA::-1::"+llList2String(llGetLinkPrimitiveParams(link,[PRIM_COLOR,f]),1)];
                        else
                        {
                            while (f<llGetLinkNumberOfSides(link))
                            {
                                data=[]+llGetLinkPrimitiveParams(link,[PRIM_COLOR,f]);
                                strToSay=[]+strToSay+[llList2String(childNamesOfInterest,l)+"::SET_ALPHA::"+(string)f+"::"+llList2String(data,1)];
                                f++;
                            }
                        }
                    }
                }
                l++;
            }
            llOwnerSay("COMMAND STRING FOR NOTECARD FOR PRIMS OF INTEREST:\nPAO_CHILD{"+llDumpList2String(strToSay,"::")+"}");
        }
    }
}
