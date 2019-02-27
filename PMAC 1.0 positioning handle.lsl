// PARAMOUR MULTI-ANIMATION CONTROLLER (PMAC) v1.0 POSITIONING HANDLE SCRIPT
// by Aine Caoimhe January 2015
// Provided under Creative Commons Attribution-Non-Commercial-ShareAlike 4.0 International license.
// Please be sure you read and adhere to the terms of this license: https://creativecommons.org/licenses/by-nc-sa/4.0/
//
// There are no settings in this script that would normally require adjustment by the user.
// Edit at your own risk 

default
{
    dataserver(key who,string message)
    {
        if (message=="HANDLE_DIE") llDie();
    }
    changed(integer change)
    {
        if (change & CHANGED_REGION_START) llDie();
    }
}
