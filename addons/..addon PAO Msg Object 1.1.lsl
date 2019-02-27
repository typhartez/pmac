// MESSAGE OBJECT ADD-ON v1.1 FOR PMAC 1.x and PMAC 2.x
// by Aine Caoimhe (c. LACM) July 2015 rev Feb 2016
// Provided under Creative Commons Attribution-Non-Commercial-ShareAlike 4.0 International license.
// Please be sure you read and adhere to the terms of this license: https://creativecommons.org/licenses/by-nc-sa/4.0/
//
// REQUIRES THAT THE OSSL COMMANDS osMessageObject() and osIsUUID() ARE ENABLED IN THE REGION (and that the target object is scripted to do something)
// 
// Command format for this addon:
// PAO_MSG_OBJECT{OBJECT_KEY::msg::...}
// or
// PAO_MSG_OBJECT{OBJECT_NAME::msg::...}
// you can message multiple objects by appending additional key::message and/or string::message pairs inside the braces
// Keep in mind that neither a named object nor the string to be sent is allowed to use any of the following characters:
//      \           used by LSL as a text flag and these are passed as strings so it would almost certainly bugger things up
//      |           reserved as a separator for PMAC core animations
//      {           reserved for as a separator for PMAC core commmands
//      }           reserved for as a separator for PMAC core commands
//      ::          reserved as a separator for this addon
// If your command needs to pass arguments with separators I suggest using something like @ or # or ^ as your separator
//
// DO NOT include any extra spaces between the separators or before/after the curly braces...a space inside a named object's name is fine but don't include any leading or trailing spaces
//
// THIS SCRIPT CAN BE CHANGED AND RESET DURING OPERATION WITHOUT CAUSING ANY ISSUES
// 
// *************************
// USER SETTINGS
// *************************
float range=32.0;           // radius of the range (in meters) to look for any named objects
//
// ***********************************************************************
// DON'T CHANGE ANYTHING BELOW THIS LINE UNLESS YOU KNOW WHAT YOU'RE DOING
// ***********************************************************************
list messages;

messageThis(key target)
{
    if (llGetListLength(llGetObjectDetails(target,[OBJECT_POS]))==0) llOwnerSay("WARNING! PAO_MSG_OBJECT addon was told to send a message to a prim with UUID "+(string)target+" but it is not in the region");
    else osMessageObject(target,llList2String(messages,1));
    messages=[]+llDeleteSubList(messages,0,1);
    sendMessages();
}
sendMessages()
{
    if (llGetListLength(messages)==0) return;
    string target=llList2String(messages,0);
    if (osIsUUID(target)) messageThis((key)target);
    else llSensor(target,NULL_KEY,0,range,PI);
}
default
{
    link_message(integer sender, integer num, string message, key sitters)
    {
        list parsed=llParseString2List(message,["|"],[]);
        string command=llList2String(parsed,0);
        if (command=="GLOBAL_NEXT_AN")
        {
            list commandBlock=llParseString2List(llList2String(parsed,1),["{","}"],[]);
            integer myBlock=llListFindList(commandBlock,"PAO_MSG_OBJECT");
            if (myBlock>=0)
            {
                messages=[]+llParseString2List(llList2String(commandBlock,myBlock+1),["::"],[]);
                sendMessages();
            }
        }
    }
    no_sensor()
    {
        llOwnerSay("WARNING! PAO_MSG_OBJECT addon was told to send a message to prim with the name \""+llList2String(messages,0)+"\" but none were found within the set range of "+(string)llRound(range)+"m");
        messages=[]+llDeleteSubList(messages,0,1);
        sendMessages();
    }
    sensor(integer num)
    {
        string text=llList2String(messages,1);
        while (--num>=0) { osMessageObject(llDetectedKey(num),text); }
        messages=[]+llDeleteSubList(messages,0,1);
        sendMessages();
    }
}
