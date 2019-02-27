// PAO-NC Multi-Props Prop Script
// by Aine Caoimhe Feb 2016
// Provided under Creative Commons Attribution-Non-Commercial-ShareAlike 4.0 International license.
// Please be sure you read and adhere to the terms of this license: https://creativecommons.org/licenses/by-nc-sa/4.0/
//
// Place this script into any prop that is intended to be used with the PAO Multi-Props add-on for PMAC 2.0
// Then place the prop into the PMAC Object's inventory along with the PAO Multi-Props add-on script
//
// There are no settings in this script that would normally require adjustment by the user.
// Edit at your own risk 

default
{
    dataserver(key who,string message)
    {
        if (message=="NC_PROP_DIE") llDie();    // I use the same prop die command as Neo Cortex's single prop system so props with his scripts can also be used with mine
    }
    changed(integer change)
    {
        if (change & CHANGED_REGION_START) llDie();
    }
}
