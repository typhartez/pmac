// PAO Simple Messenger Add-On v1.0
// by Aine Caoimhe (LACM) February 2016)
//
// Provided under Creative Commons Attribution-Non-Commercial-ShareAlike 4.0 International license.
// Please be sure you read and adhere to the terms of this license: https://creativecommons.org/licenses/by-nc-sa/4.0/
//
// REQUIRES THAT THE OSSL COMMAND osMessageObject() IS ENABLED IN THE REGION
//
// This add-on is a simple messenger to notify an external object (separate prim/linkset in the region) when a PMAC system switches between "READY" and "RUNNING" states
// PMAC is normally in READY state when nobody is using it, then switches to RUNNING when the first person/NPC sits on it, then back to READY when the last person stands
//
// To set the system up, you will need to supply a list of messages with:
// - either the name or the UUID of the object you want to send a message to
//      - if you supply a UUID, the message is sent only to that object but the object can be ANYWHERE in the same region (even if it's hundreds of meters away in a var)
//      - if you supply a name, the message is sent to ALL objects that have that exact name and are within the "range" you set (a sphere with a radius of the range value)
// - a "message on" message, which is the string you want sent to the target object(s) when someone starts to use PMAC and it switches to "RUNNING" state (it will raise a dataserver event in a script located in the root prim of that object)
// - a "message off" message, which is the string you want sent to the target object(s) when the PMAC system returns to its idle "READY" state (again, this raises a dataserver event in any script located in the root prim of that object)
// - if you're using any messages to named items, you also need to specify a range but you need to be aware of some limitations:
//      - by default, Opensim will only return the keys of the first 16 objects it finds...there is a setting in Opensim.ini [XEngine] section that allows you to increase this limit
//      - by default, the maximum range for detection is 96.0m but this can also be extended via a setting in the Opensim.ini [XEngine] section...note that the larger the range, the more of an impact it has on the sim
// You can have multiple different targets, each with its own message
// If you want to send the same message to several different targets you can supply them as a pipe-separated string and you can mix and match between names and UUIDs in that sub-list
// You can send more than one message to the same object but eash is handled/sent as a separate message...due to asynchronous handling used by Opensim, there is no guarantee of the exact sequence that targets will receive their messages
// so don't count on any specific order/chain of events. If you need that to happen you'll need to script something more complex that handles its own sequencing
// 
// Example
// in the user settings you could have something like this:
//        list messages=[
//            "spotlight", "NOTICE_SYSTEM_ON", "NOTICE_SYTSTEM_OFF",
//            "curtain|bab9c37b-fe88-4032-85f2-908b189810c8","CURTAIN_OPEN","CURTAIN_CLOSE",
//            "bab9c37b-fe88-4032-85f2-908b189810c8","ALSO_SEND_THIS_WHEN_ON","ALSO_SEND_THIS_WHEN_OFF"
//            ];
//        float range 20.0;
// When PMAC becomes active, it will search for any objects with the name "spotlight" that are within 20m of the PMAC controller. It will send the message "NOTICE_SYSTEM_ON" to any it finds.
// Then it will look for any objects with the name "curtain" that are within 20m of the PMAC controller and send a "CURTAIN_OPEN" message to them
// It will also send the message "CURTAIN_OPEN" to the object with the specified key, no matter where it is in the region (it will warn you if it can't find the object)
// And then finally it will send the message "ALSO_SEND_THIS_WHEN_ON" to the object with the specified key if it can find it. Since it's the same key as the second message, that object will receive 2 messages, each of which raises a dataserver event
// 
// ********************
// USER SETTINGS
// ********************
//
list messages=[ // (string) target, (string) message on, (string) message off

    ];
float range=32.0;   // range to look for any named target...by default the maximum range is 96.0m and is limited to 16 results unless you've changed these limnits in the Opensim.ini [XEngine] section of the region...avoid large values unless essential
//
// ********************************************************************
//  DO NOT CHANGE ANYTHING BELOW HERE UNLESS YOU KNW WHAT YOU'RE DOING!
// ********************************************************************

integer sendInd=0;
integer mesInd=0;
integer sending=FALSE;
list targets;
string this;

messageThis(key who)
{
    if (llGetObjectDetails(who,[OBJECT_NAME])!=[]) osMessageObject(who,llList2String(messages,sendInd+mesInd));
    else llOwnerSay("WARNING: PAO Simple Messenger was asked to send a message to an object with the key \""+(string)who+"\" but no object could be found in the region with that key");
    sendMessage(mesInd);
}
sendMessage(integer ind)
{
    if (!sending)
    {
        sendInd=0;
        mesInd=ind;
        targets=[]+llParseString2List(llList2String(messages,sendInd),["|"],[]);
        sending=TRUE;
    }
    if (llGetListLength(targets)==0)
    {
        sendInd+=3;
        if (sendInd>=llGetListLength(messages))
        {
            sending=FALSE;
            return;
        }
        else targets=[]+llParseString2List(llList2String(messages,sendInd),["|"],[]);
    }
    this=""+llList2String(targets,0);
    targets=[]+llDeleteSubList(targets,0,0);
    if (osIsUUID(this)) messageThis(this);
    else llSensor(this,NULL_KEY,0,range,PI);
}
default
{
    link_message (integer sender, integer num, string message, key id)
    {
        if (num!=0) return;
        list parsed=llParseString2List(message,["|"],[]);
        string command=llList2String(parsed,0);
        if ((command=="GLOBAL_SYSTEM_RESET")||(command=="GLOBAL_SYSTEM_GOING_DORMANT")) sendMessage(2);
        else if (command=="GLOBAL_START_USING") sendMessage(1);
    }
    no_sensor()
    {
        llOwnerSay("WARNING: PAO Simple Messenger was asked to send message to objects with the name \""+this+"\" but I wasn't able to detect any within range");
        sendMessage(mesInd);
    }
    sensor(integer num)
    {
        while (--num>=0) { osMessageObject(llDetectedKey(num),llList2String(messages,sendInd+mesInd)); }
        sendMessage(mesInd);
    }
}
