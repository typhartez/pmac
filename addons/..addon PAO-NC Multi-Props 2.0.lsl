// PAO-NC Multi-Props v2.0 Add-On for PMAC
// By Aine Caoimhe (LACM) based on the NC Props 1.x add-on by Neo Cortex
// February 2016
// Provided under Creative Commons Attribution-Non-Commercial-ShareAlike 4.0 International license.
// Please be sure you read and adhere to the terms of this license: https://creativecommons.org/licenses/by-nc-sa/4.0/
// 
// This script is based on the general mechanism and approach used by the NC Props 1.x add-on written by Neo Cortex
// but adapted and reworked to allow rezzing multiple props per animation and greater efficiency (and a slight load reduction)
// Neo had hoped to be able to write the revised version but ran out of time so I volunteered to do it instead.
//
// QUICK INSTRUCTIONS (see the companion READ ME notecard for more detailed instructions)
// This add-on rezzes any number of props (including a single prop) whenever an animation is played that has a command to use one
// Expected command format is: NC_PROP{string prop_1_name::vector prop_1_position::rotation prop_1_rotation::..........}
// You can rez the same prop multiple times for a single animation if you want to.
//
// When creating a new prop:
// - add the script ".PAO-NC Multi-Props Prop Script 2.0" to its contents before placing it into the PMAC object
// - add a suitable NC_PROP{} command to the command block for any animation you want to have rez one or more props
// - add the "PAO-NC Multi-Props v2.0" script to the PMAC Object (this script)
//
// This script uses the following OSSL functions so they must be enabled for the owner in the region:
// - osMessageObject()      // to communicate with a rezzed prop to kill it
// - osSetPrimitiveParams() // to move a prop
// Also it (obviously) rezzes an object so it needs to be owned by someone with sufficient permission to rez an object in the parcel
//
// IMPORTANT - COMPATIBILITY/CONFLICT ISSUES between this add-on and the NC Props add-on
// This script is intended to replace existing NC Props v1.x scripts and they are mutually incompatible. You CAN NOT have both in the same system
// The script inside the props of previous NC Props v1.x scripts are compatible with PMAC 2.0 and don't need to be changed to use the new one, but the new one is fractionally lighter on resources)
// This version can read the commands used in existing NC Props IF YOU SET THE VALIDATE ROTATIONS OPTION TO TRUE. If you don't, position will be correct but rotation won't.
// See the READ ME for details.
//
// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
// USER SETTINGS:
integer validateRotations=FALSE;
// If TRUE, the add-on will check each supplied props command and, if it contains only a single prop, will then check to see if the rotation is
// supplied as a vector (legacy NC Props 1.x) or rotation (new multi-props) and then both warn you and temporarily convert it to a rotation to
// allow it to be positioned correctly.
// This process will result in a slight performance slow-down of the add-on but allows it to be used in system that has the legacy data in it.
// You can enter edit mode, update all of the positions, then store the new data and change this back to FALSE once you're sure that all the values have been updated to rotations.
// In the event that you fail to convert one and have this set to FALSE, the prop will still be rezzed and positioned correctly but the prop's rotation will be incorrect
// If FALSE, no check is done and performance will be faster and more efficient (default)
// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
//
// Don't change anything below here unless you know what you're doing!
//
list currentProps=[];   // (key) prop UUID | (string) prop_object   -- list of props currently rezzed and in use
list nextProps=[];      // (string) prop_object | (vector) pos | (rotation) rot -- list of props needed for the next animation
integer rezzing=FALSE;  // flag...to indicate that this script is in the process of rezzing items

doProps()
{
    // first reposition any props that have already been rezzed and remove any unneeded props
    if (!rezzing)
    {
        list keeping=[]; // temp holding list for the props that don't need to be removed
        while (llGetListLength(currentProps)>0)
        {
            key object=llList2Key(currentProps,0);
            string name=llList2String(currentProps,1);
            integer i=llListFindList(nextProps,[name]);
            if (i==-1)
            {
                // prop not used for next animation...remove it
                if (object==NULL_KEY) llOwnerSay("WARNING! NULL_KEY value for stored prop object was called when Multi-props was checking an existing prop with name: "+name);
                else {
                    if (llGetObjectDetails(object,[OBJECT_NAME])==[])llOwnerSay("WARNING! Unable to locate expected prop object \""+name+"\" when Multi-props was attempting to remove it from the scene");
                    else osMessageObject(object,"NC_PROP_DIE");
                }
            }
            else
            {
                // reusing this prop...move it to new location, put it in the holding list, and remove it from the list of props we need to rez
                list loc=relToReg(llList2Vector(nextProps,i+1),llList2Rot(nextProps,i+2));
                osSetPrimitiveParams(object,[PRIM_POSITION,llList2Vector(loc,0),PRIM_ROTATION,llList2Rot(loc,1)]);
                nextProps=[]+llDeleteSubList(nextProps,i,i+2);
                keeping=[]+keeping+[object,name];
            }
            currentProps=[]+llDeleteSubList(currentProps,0,1);
        }
        currentProps=[]+keeping;
    }
    // any remaining items in the nextProps list are ones we need to rez
    rezzing=FALSE;
    integer valid=FALSE;
    while ((llGetListLength(nextProps)>0) && (!valid))
    {
        // make sure it exists in inventory
        string item=llList2String(nextProps,0);
        if (llGetInventoryType(item)!=INVENTORY_OBJECT)
        {
            llSay(0,"ERROR! Multi-props was told to rez an object \""+item+"\" but it was not found in inventory. Skipping it...");
            nextProps=[]+llDeleteSubList(nextProps,0,2);
        }
        else
        {
            valid=TRUE; // found a prop we can rez..set flags
            rezzing=TRUE;
            list loc=relToReg(llList2Vector(nextProps,1),llList2Rot(nextProps,2));
            llRezAtRoot(item,llList2Vector(loc,0),ZERO_VECTOR,llList2Rot(loc,1),1);
            // will triggerobject-rez which sends back to this loop
        }
    }
}
removeAll()
{
    nextProps=[];
    rezzing=FALSE;
    doProps();
}
list regToRel(vector regionPos,rotation regionRot) {
    vector relPos=(regionPos - llGetPos()) / llGetRot();
    rotation relRot=regionRot/ llGetRot();
    return [relPos,relRot];
}
list relToReg(vector refPos,rotation refRot) {
    vector regionPos=refPos*llGetRot()+llGetPos();
    rotation regionRot=refRot*llGetRot();
    return [regionPos,regionRot];
}
string trimF(float value) {
    string retStr=(string)(((float)llRound(value*10000))/10000.0);
    while (llGetSubString(retStr,-1,-1)=="0") { retStr=llGetSubString(retStr,0,-2);}
    return retStr;
}
doSafetyCheck()
{
    integer i=llGetInventoryNumber(INVENTORY_SCRIPT);
    while (--i>=0) { if (llSubStringIndex(llGetInventoryName(INVENTORY_SCRIPT,i),"..addon NC Props")>-1) llOwnerSay("ERROR!!! You have both the PAO-NC Multi-Props v2.0 and older NC Props v1.x add-ons in this PMAC system but they are NOT compatible with one another. Please delete the older NC Props v1.x add-on to avoid potentially serious incompatibilty issues"); }
}
default
{
    state_entry()
    {
        if (llGetAttached()!=0) return;
        doSafetyCheck();
        removeAll(); // even though they already should be in most cases
    }
    object_rez(key object)
    {
        if (!rezzing) return;   // only pay attention if we're actively rezzing (ignore PMAC rezzing handles, etc)
        // just in case another add-on is rezzing something make sure this object name matches the expected on
        string name=llList2String(llGetObjectDetails(object,[OBJECT_NAME]),0);
        if (name!=llList2String(nextProps,0)) return;
        // getting here means it's the prop we rezzed so add it to the current props list and remove it from the needed list
        currentProps=[]+currentProps+[object,name];
        nextProps=[]+llDeleteSubList(nextProps,0,2);
        // loop it back to props rezzing
        doProps();
    }
    link_message (integer sender, integer num, string message, key id)
    {
        if (num!=0) return; // ignore anything not set on internal global channel 0
        list parsed=llParseString2List(message,["|"],[]);
        string command=llList2String(parsed,0);
        if (command=="GLOBAL_NEXT_AN")
        {
            list commandBlock=llParseString2List(llList2String(parsed,1),["{","}"],[]);
            integer myBlock=llListFindList(commandBlock,["NC_PROP"]);
            if(myBlock>=0)
            {
                nextProps=[]+llParseString2List(llList2String(commandBlock,myBlock+1),["::"],[]);
                if (validateRotations)
                {
                    if (llGetListLength(nextProps)==3)
                    {
                        // this could be a legacy NC_PROPS command so validate rotation and replace if it is a vector
                        if (llGetListLength(llParseString2List(llGetSubString(llList2String(nextProps,2),1,-2),[","],[]))==3) // nested instead of &&ed because it's more efficient
                        {
                            llOwnerSay("Multi-props read a props value with rotation supplied as vector and converted it to a rotation. Please see the multi-props READ ME for recommendations");
                            vector vRot=llList2Vector(nextProps,2);
                            rotation rRot=llEuler2Rot(vRot*DEG_TO_RAD);
                            nextProps=[]+llListReplaceList(nextProps,[rRot],2,2);
                        }
                    }
                }
            }
            else nextProps=[];
            rezzing=FALSE;
            doProps();
        }
        else if (command=="GLOBAL_SYSTEM_RESET")
        {
            removeAll();
            llResetScript();
        }
        else if (command=="GLOBAL_SYSTEM_GOING_DORMANT")
        {
            removeAll();
        }
        else if (command=="GLOBAL_STORE_ADDON_NOTICE")
        {
            // update prop data
            integer p=llGetListLength(currentProps);
            if (p==0) return;
            string newData;
            integer i;
            while (i<p)
            {
                key thisKey=llList2Key(currentProps,i);
                string thisName=llList2String(currentProps,i+1);
                list regLoc=llGetObjectDetails(thisKey,[OBJECT_POS,OBJECT_ROT]);
                if (regLoc==[])
                {
                    llOwnerSay("ERROR! Attempting to store new position for multi-props add-on but the expected prop \""+thisName+"\" was not found in the scene. Aborting!");
                    return;
                }
                list relLoc=regToRel(llList2Vector(regLoc,0),llList2Rot(regLoc,1));
                vector newPos=llList2Vector(relLoc,0);
                rotation newRot=llList2Rot(relLoc,1);
                if (llStringLength(newData)>0) newData+="::";
                newData+=thisName+"::<"+trimF(newPos.x) + "," + trimF(newPos.y) + "," + trimF(newPos.z) + ">::<"+trimF(newRot.x) + "," + trimF(newRot.y) + "," + trimF(newRot.z) + "," + trimF(newRot.s) + ">";
                i+=2;
            }
            llMessageLinked(LINK_THIS,-1,"NC_PROP_UPDATE "+newData,NULL_KEY);
        }
    }
}
