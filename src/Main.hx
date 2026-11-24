
package mods.online_tracker;

import mods.api.Context;
import mods.api.Mod;

import brain.stateMachine.State;
import brain.stateMachine.StateMachine;
import brain.uI.UIButton;
import distributedObjects.PresenceManager;

import town.HomeState;

import account.FriendInfo;
import account.GiftInfo;
import distributedObjects.MatchMaker;

import stateMachine.mainStateMachine.LoadingScreenState;

class Main extends Mod {

    private var context:Context;
    private var activityStore:ActivityStore;
    private var leastActiveOverlay:LeastActiveOverlay;
    public static var externalGifts:Array<GiftInfo> = [];

    override public function init(context:Context):Void {
        this.context = context;

        activityStore = new ActivityStore(context);

        // Create the overlay manager
        leastActiveOverlay = new LeastActiveOverlay(context,activityStore);

        context.core.onObjectReady(function(object) {
            if (Std.isOfType(object, PresenceManager)) {
                var manager:PresenceManager = cast object;

                context.log("PresenceManager erstellt!");
                subscribePresenceManager(manager);
            }
        });
        

        // Enter states
        context.core.onStateEnter(function(machine:StateMachine, state:State) {
            if (Type.getClassName(Type.getClass(state)) == "town.SocialSubState") {
                leastActiveOverlay.start(state);
            } 
        });

        // Exit states
        context.core.onStateExit(function(machine:StateMachine, state:State) {

            // Leave SocialSubState
            if (Type.getClassName(Type.getClass(state)) == "town.SocialSubState") {
                leastActiveOverlay.stop();
            }
            if (Std.isOfType(state, HomeState)){
                var homeState:HomeState = cast state;
                var accountInfo = homeState.mDBFacade.dbAccountInfo;
                loadGifts(accountInfo);
                loadOnline(accountInfo);
                getFriendDataFromExternal();

            }    
        });
    }
    override public function ready(context:Context):Void {
        this.context = context;

        var facade:Dynamic = Reflect.getProperty(context.core, "facade");

        if (facade == null) {
            context.log("ERROR: facade ist null!");
            return;
        }

        var accountInfo:Dynamic = Reflect.getProperty(facade, "dbAccountInfo");

        if (accountInfo == null) {
            context.log("ERROR: dbAccountInfo ist null!");
            return;
        }

        accountInfo.getFriendData(function() {
            context.log("Freundesdaten vom Server geladen!");
            loadOnline(accountInfo);
        });

        accountInfo.getGiftData(function() {
            context.log("Geschenkdaten vom Server geladen!");
            loadGifts(accountInfo);
        });
    }

    override public function dispose():Void {
        var facade:Dynamic = Reflect.getProperty(context.core, "facade");
        if (facade == null) {
            context.log("ERROR: facade ist null!");
            return;
        }
        var accountInfo:Dynamic = Reflect.field(facade, "mDBAccountInfo");
        if (accountInfo == null) {
            context.log("ERROR: dbAccountInfo ist null!");
            return;
        }
        loadOnline(accountInfo);
        getFriendDataFromExternal();
    }

    // --------------------------------
    // Gifts
    // --------------------------------

    public function loadGifts(accountInfo:Dynamic):Void {

        if (accountInfo == null) {
            context.log("ERROR: accountInfo is null!");
            return;
        }

        var gifts:Dynamic = Reflect.getProperty(accountInfo, "gifts");

        if (gifts == null) {
            context.log("ERROR: gifts is null!");
            return;
        }

        var keysToArray = Reflect.field(gifts, "keysToArray");
        var itemFor = Reflect.field(gifts, "itemFor");

        if (keysToArray == null || itemFor == null) {
            context.log("ERROR: Gift map methods not found!");
            return;
        }

        var keys:Dynamic = Reflect.callMethod(gifts, keysToArray, []);

        if (keys == null) {
            context.log("ERROR: keys is null!");
            return;
        }
        context.log("Anzahl Geschenke: " + keys.length);

        var giftIds:Array<String> = activityStore.getAllGiftIds();
        var requestIds:Array<String> = [];
        var accountIds:Array<UInt> = [];

        for (key in keys) {

            var gift:Dynamic = Reflect.callMethod(gifts, itemFor, [key]);

            if (gift == null)
                continue;

            var requestId:String = Reflect.getProperty(gift, "mRequestId");

            if (requestId == null)
                continue;

            requestIds.push(requestId);

            if (giftIds.contains(requestId))
                continue;

            var accountId:UInt = Reflect.getProperty(gift, "mFromAccountId");

            if (!accountIds.contains(accountId))
                accountIds.push(accountId);
        }

        if (accountIds.length > 0)
            activityStore.recordActivities(accountIds);

        activityStore.syncGifts(requestIds);
    }

    public function loadOnline(accountInfo:Dynamic):Void {
        var friendsInfo:Dynamic = Reflect.field(accountInfo, "mFriendsInfo");

        if (friendsInfo == null)
            return;

        var keys:Dynamic = friendsInfo.keysToArray();
        var accountIds:Array<UInt> = [];

        for (i in 0...keys.length) {
            var accountId:UInt = keys[i];
            var friendInfo:Dynamic = friendsInfo.itemFor(accountId);

            if (friendInfo == null)
                continue;

            if (friendInfo.isOnline())
                accountIds.push(accountId);
        }
        context.log("Anzahl Account-IDs: " + accountIds.length);

        for (accountId in accountIds) {
            context.log("Account ID: " + Std.string(accountId));
        }


        if (accountIds.length > 0)
            activityStore.recordActivities(accountIds);
    }

    // --------------------------------
    //  subscribePresenceManager
    // --------------------------------

    private function subscribePresenceManager(manager:PresenceManager):Void {
        var eventComponent:Dynamic = Reflect.field(
            manager,
            "mEventComponent"
        );

        if (eventComponent == null) {
            context.log("PresenceManager EventComponent nicht gefunden!");
            return;
        }

        eventComponent.addListener(
            "FRIEND_STATUS_EVENT",
            onFriendStatus
        );

        context.log("FRIEND_STATUS_EVENT abonniert!");
    }

    private function onFriendStatus(event:Dynamic):Void {
        var friendId:UInt = cast Reflect.field(event, "mFriendId");

        activityStore.recordActivities(friendId);
    }

    // --------------------------------
    // getGiftDataFromExternal
    // --------------------------------


    private function getFriendDataFromExternal():Void {
        var gifts:Array<GiftInfo> = cast getOtherVariable("externalGifts");
        var giftIds:Array<String> = activityStore.getAllGiftIds();
         var accountIds:Array<UInt> = [];

        if (gifts == null) {
            context.log("Could not retrieve friendIds from OnlineTracker!");
            return;
        }

        for (gift in gifts) {
            if (gift == null)
                continue;
            var requestId:String = Reflect.getProperty(gift, "mRequestId");

            if (requestId == null || giftIds.contains(requestId))
                continue;

            var accountId:UInt = Reflect.getProperty(gift, "mFromAccountId");
    

            accountIds.push(accountId);
        }


      if (accountIds.length > 0)
            activityStore.recordActivities(accountIds);
    }

    private function getOtherVariable(name:String):Dynamic {
        var cls = Type.resolveClass("mods.online_tracker.Main");

        if (cls == null) {
            context.log("OnlineTracker class not found!");
            return null;
        }

        var value = Reflect.field(cls, name);

        if (value == null) {
            context.log("Field '" + name + "' not found or is null!");
            return null;
        }

        if (Std.isOfType(value, Array)) {
            var result:Array<Dynamic> = (cast value:Array<Dynamic>).copy();

            // Ursprüngliches Array zurücksetzen
            (cast value:Array<Dynamic>).resize(0);

            return result;
        }

        // Andere Variablentypen auf null zurücksetzen
        Reflect.setField(cls, name, null);

        return value;
    }
}



