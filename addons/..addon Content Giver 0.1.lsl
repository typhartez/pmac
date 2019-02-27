//I'm not great at scripting, I made this reading the manuals that comes with the PMAC system
//and inspecting the PAO Expressions and NC Props addons.  Without them this would be as effective as a potato.

//Do whatever you want with this script, but don't be an ass and credit me, otherwise I'll... cry or something.
//Aaack Aardvark, LittleField Grid, 2015.

string buttonName = "Get Items";
default
{
    state_entry()
    {
        if (llGetInventoryKey(".ToGive") == NULL_KEY)
        {
            llSay(0, "The notecard .ToGive is missing, please add it so I can give the objects");
        }
    }
    link_message (integer sender, integer num, string message, key id)
    {
        list parsed = llParseString2List(message,["|"],[]);
        string command = llList2String(parsed,0);
        list newUsers = llParseString2List(id,["|"],[]);
        if (command == "GLOBAL_SYSTEM_RESET")
        {
            llResetScript();
        }
        else if (command == "GLOBAL_NEW_USER_ASSUMED_CONTROL")
        {
            llMessageLinked(LINK_THIS,-1,"MAIN_REGISTER_MENU_BUTTON|"+buttonName,"ping");
        }
        else if (command == "ping")
        {
            if (llGetInventoryKey(".ToGive") == NULL_KEY)
            {
                llSay(0, "The notecard .ToGive is missing, please add it so I can give the items.");
            }
            else
            {
                key who = (key)llList2String(parsed,1);
                string give = osGetNotecard(".ToGive");
                list togive = llParseString2List(give, ["\n"], [""]);
                llGiveInventoryList(who, llGetObjectName(), togive);
                llSay(0, "Delivering your items, check for a new folder called '" + llGetObjectName() + "'.");
                llMessageLinked(LINK_THIS,-1,"MAIN_RESUME_MAIN_DIALOG",NULL_KEY);
            }
        }
    }
}
