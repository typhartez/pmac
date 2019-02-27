// MESSAGE SITTERS ADD-ON FOR PMAC 1.x
// by Aine Caoimhe (c. LACM) July 2015
// Provided under Creative Commons Attribution-Non-Commercial-ShareAlike 4.0 International license.
// Please be sure you read and adhere to the terms of this license: https://creativecommons.org/licenses/by-nc-sa/4.0/
//
// REQUIRES THAT THE OSSL COMMAND osMessageAttachments() IS ENABLED IN THE REGION (and that any attachments that need to react to it are scripted to do so)
// 
// Command format for this addon:
// PAO_MSG_SITTERS{msg_sitter1::msg)sitter2::....}
// where for each sitter you must either supply the string to be sent or PAO_NO_MSG if no message is to be sent to that sitter
// Keep in mind that the string to be sent cannot use any of the following characters:
//      \           used by LSL as a text flag and these are passed as strings so it would almost certainly bugger things up
//      |           reserved as a separator for PMAC core animations
//      {           reserved for as a separator for PMAC core commands
//      }           reserved for as a separator for PMAC core commands
//      ::          reserved as a separator for this add-on
// If your command needs to pass arguments I suggest using something like @ or # or ^ as your separator
//
// DO NOT include any extra spaces between the separators or before/after the curly braces
//
// USER VARIABLES
// none
//
// THIS SCRIPT ITSELF CAN BE CHANGED AND RESET DURING OPERATION WITHOUT CAUSING ANY ISSUES

default
{
    link_message(integer sender, integer num, string message, key sitters)
    {
        list parsed=llParseString2List(message,["|"],[]);
        string command=llList2String(parsed,0);
        if (command=="GLOBAL_NEXT_AN")
        {
            list commandBlock=llParseString2List(llList2String(parsed,1),["{","}"],[]);
            list mySitters=llParseString2List(sitters,["|"],[]);
            integer myBlock=llListFindList(commandBlock,"PAO_MSG_SITTERS");
            if (myBlock>=0)
            {
                list myData=llParseString2List(llList2String(commandBlock,myBlock+1),["::"],[]);
                if (llGetListLength(myData)!=llGetListLength(mySitters)) llOwnerSay("ERROR! PAO_MSG_SITTERS had a mismatch in the number of messages to send vs the number of sitter called for by this animation group");
                else
                {
                    integer s=llGetListLength(mySitters);
                    while (--s>=0)
                    {
                        key who=llList2Key(mySitters,s);
                        string msgToSend=llList2String(myData,s);
                        if ((msgToSend!="PAO_NO_MSG")&&(who!=NULL_KEY)) osMessageAttachments(who,msgToSend,[OS_ATTACH_MSG_ALL], 0);
                    }
                }
            }
        }
    }
}
