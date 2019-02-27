// EXPRESSIONS ADD-ON FOR PMAC 1.0
// by Aine Caoimhe (Mata Hari)(c. LACM) January 2015
// Provided under Creative Commons Attribution-Non-Commercial-ShareAlike 4.0 International license.
// Please be sure you read and adhere to the terms of this license: https://creativecommons.org/licenses/by-nc-sa/4.0/
//
// Command format for this addon:
// PAO_EXPRESS{e::t::....}
// where for each position you need to supply both
//      e = the expression number to play as per the list below
//      t = how often to repeat it in seconds (or 0 for no repeat)
// unlike MLP, if you want an animation to use an expression for any of the positions you *must* supply both expression # and a time for each position, even if most are 0::0.0
// DO NOT include any extra spaces between the separators or before/after the curly braces

list expressions=[
        "0",                            // 0 none
        "express_open_mouth",           // 1
        "express_surprise_emote",       // 2
        "express_tongue_out",           // 3
        "express_smile",                // 4
        "express_toothsmile",           // 5
        "express_wink_emote",           // 6
        "express_cry_emote",            // 7
        "express_kiss",                 // 8
        "express_laugh_emote",          // 9
        "express_disdain",              // 10
        "express_repulsed_emote",       // 11
        "express_anger_emote",          // 12
        "express_bored_emote",          // 13
        "express_sad_emote",            // 14
        "express_embarrassed_emote",    // 15
        "express_frown",                // 16
        "express_shrug_emote",          // 17
        "express_afraid_emote",         // 18
        "express_worry_emote",          // 19
        "10+4"                          // 20 sleep
    ];
list positions;
list currentExp;
float expTimer;

zeroAll()
{
    positions=[];
    currentExp=[];
    expTimer=0.0;
}
stopExpress()
{
    llSetTimerEvent(0.0);
    integer i=llGetListLength(positions);
    while (--i>=0)
    {
        key who=llList2Key(positions,i);
        if (who!=NULL_KEY)
        {
            integer expIndex=llList2Integer(currentExp,i*2);
            if (expIndex==20)
            {
                osAvatarStopAnimation(who,llList2String(expressions,10));
                osAvatarStopAnimation(who,llList2String(expressions,4));
            }
            else if (expIndex) osAvatarStopAnimation(who,llList2String(expressions,expIndex));
        }
    }
}
startExpress()
{
    expTimer=0.0;
    integer i=llGetListLength(positions);
    while (--i>=0)
    {
        key who=llList2Key(positions,i);
        if (who!=NULL_KEY)
        {
            integer expIndex=llList2Integer(currentExp,i*2);
            if (llList2Float(currentExp,i*2+1)>expTimer) expTimer=llList2Float(currentExp,i*2+1);
            if (expIndex==20)
            {
                osAvatarPlayAnimation(who,llList2String(expressions,10));
                osAvatarPlayAnimation(who,llList2String(expressions,4));
            }
            else if (expIndex) osAvatarPlayAnimation(who,llList2String(expressions,expIndex));
        }
    }
    llSetTimerEvent(expTimer);
}
default
{
    state_entry()
    {
        zeroAll();  // even though they already should be
    }
    timer()
    {
        integer i=llGetListLength(positions);
        while(--i>=0)
        {
            key who=llList2Key(positions,i);
            if (who!=NULL_KEY)
            {
                if (llList2Float(currentExp,i*2+1)>0.0)
                {
                    integer expIndex=llList2Integer(currentExp,i*2);
                    if (expIndex==20)
                    {
                        osAvatarStopAnimation(who,llList2String(expressions,10));
                        osAvatarStopAnimation(who,llList2String(expressions,4));
                        osAvatarPlayAnimation(who,llList2String(expressions,10));
                        osAvatarPlayAnimation(who,llList2String(expressions,4));
                    }
                    else if (expIndex)
                    {
                        osAvatarStopAnimation(who,llList2String(expressions,expIndex));
                        osAvatarPlayAnimation(who,llList2String(expressions,expIndex));
                    }
                }
            }
        }
    }
    link_message (integer sender, integer num, string message, key id)
    {
        list parsed=llParseString2List(message,["|"],[]);
        string command=llList2String(parsed,0);
        list newUsers=llParseString2List(id,["|"],[]);
        if (command=="GLOBAL_NEXT_AN")
        {
            stopExpress();
            list commandBlock=llParseString2List(llList2String(parsed,1),["{","}"],[]);
            integer myBlock=llListFindList(commandBlock,"PAO_EXPRESS");
            if(myBlock>=0)
            {
                positions=[]+newUsers;
                currentExp=[]+llParseString2List(llList2String(commandBlock,myBlock+1),["::"],[]);
                startExpress();
            }
            else zeroAll();
        }
        else if (command=="GLOBAL_ANIMATION_SYNCH_CALLED")
        {
            stopExpress();
            startExpress();
        }
        else if (command=="GLOBAL_SYSTEM_RESET") llResetScript();
        else if (command=="GLOBAL_SYSTEM_GOING_DORMANT") zeroAll();
        else if (command=="GLOBAL_USER_STOOD")
        {
            key who=llList2Key(parsed,2);
            integer ind=llListFindList(positions,[who]);
            if (ind>=0)
            {
                if (llGetAgentSize(who)!=ZERO_VECTOR) osAvatarStopAnimation(who,llList2String(expressions,llList2Integer(currentExp,ind)));
                positions=[]+newUsers;
            }
        }
    }
}
