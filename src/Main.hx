
package mods.online_tracker;

import mods.api.Context;
import mods.api.Mod;

import brain.stateMachine.State;
import brain.stateMachine.StateMachine;

import distributedObjects.PresenceManager;

import town.HomeState;

import account.GiftInfo;

import flash.events.Event;

class Main extends Mod {

    private var context:Context;
    private var activityStore:ActivityStore;
    private var leastActiveOverlay:LeastActiveOverlay;


    override public function init(context:Context):Void {
        this.context = context;

        activityStore = new ActivityStore(context);

        // Create the overlay manager
        leastActiveOverlay = new LeastActiveOverlay(context, activityStore);

        // Listen for newly created game objects
        context.core.onObjectReady(function(object) {
            if (Std.isOfType(object, PresenceManager)) {
                var manager:PresenceManager = cast object;

                subscribePresenceManager(manager);

                var presence:Dynamic = Reflect.getProperty(manager, "mPresence");

                if (presence == null) {
                    context.log("ERROR: mPresence is null!");
                    return;
                }

                var keysToArray = Reflect.field(presence, "keysToArray");

                if (keysToArray == null) {
                    context.log("ERROR: keysToArray method not found!");
                    return;
                }

                var keys:Array<Dynamic> = cast Reflect.callMethod(
                    presence,
                    keysToArray,
                    []
                );

                if (keys == null) {
                    context.log("ERROR: Presence keys are null!");
                    return;
                }

                context.log("Number of presence entries: " + keys.length);

                var accountIds:Array<UInt> = [];

                for (accountId in keys) {
                    if (manager.isOnline(cast accountId)) {
                        context.log("ONLINE FRIEND ID: " + Std.string(accountId));
                        accountIds.push(accountId);
                    }
                }

                if (accountIds.length > 0) {
                    activityStore.recordActivities(accountIds);
                }
            }
        });

        // Handle state transitions
        context.core.onStateEnter(function(machine:StateMachine, state:State) {
            if (Type.getClassName(Type.getClass(state)) == "town.SocialSubState") {
                leastActiveOverlay.start(state);
            }
        });

        context.core.onStateExit(function(machine:StateMachine, state:State) {

            // Handle leaving the social state
            if (Type.getClassName(Type.getClass(state)) == "town.SocialSubState") {
                leastActiveOverlay.stop();
            }
        });
    }

    override public function ready(context:Context):Void {
        this.context = context;

        var facade:Dynamic = Reflect.getProperty(context.core, "facade");

        if (facade == null) {
            context.log("ERROR: facade is null!");
            return;
        }

        var accountInfo:Dynamic = Reflect.getProperty(facade, "dbAccountInfo");

        if (accountInfo == null) {
            context.log("ERROR: dbAccountInfo is null!");
            return;
        }

        accountInfo.getGiftData(function() {
            context.log("Gift data successfully loaded from the server!");

            loadGifts(accountInfo);

            var facade:Dynamic = Reflect.getProperty(context.core, "facade");
            var eventManager:Dynamic = Reflect.getProperty(facade, "eventManager");

            if (eventManager == null) {
                context.log("ERROR: eventManager is null!");
                return;
            }

            var event = new Event("GIFTS_LOADED_EVENT");

            var dispatchMethod = Reflect.field(eventManager, "dispatchEvent");

            if (dispatchMethod != null) {
                Reflect.callMethod(eventManager, dispatchMethod, [event]);
                context.log("GIFTS_LOADED_EVENT dispatched!");
            } else {
                context.log("ERROR: dispatchEvent is null!");
            }
        });
    }

    // --------------------------------
    // Gift handling
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
            context.log("ERROR: Gift keys are null!");
            return;
        }

        context.log("Number of gifts: " + keys.length);

        var giftIds:Array<String> = activityStore.getAllGiftIds();
        var requestIds:Array<String> = [];
        var accountIds:Array<UInt> = [];

        for (key in keys) {
            var gift:Dynamic = Reflect.callMethod(gifts, itemFor, [key]);

            if (gift == null) {
                continue;
            }

            var requestId:String = Reflect.getProperty(gift, "mRequestId");

            if (requestId == null) {
                continue;
            }

            requestIds.push(requestId);

            if (giftIds.contains(requestId)) {
                continue;
            }

            var accountId:UInt = Reflect.getProperty(gift, "mFromAccountId");

            if (!accountIds.contains(accountId)) {
                accountIds.push(accountId);
            }
        }

        if (accountIds.length > 0) {
            activityStore.recordActivities(accountIds);
        }

        activityStore.syncGifts(requestIds);
    }

    // --------------------------------
    // Presence manager subscriptions
    // --------------------------------

    private function subscribePresenceManager(manager:PresenceManager):Void {
        var eventComponent:Dynamic = Reflect.field(
            manager,
            "mEventComponent"
        );

        if (eventComponent == null) {
            context.log("ERROR: PresenceManager EventComponent not found!");
            return;
        }

        eventComponent.addListener(
            "FRIEND_STATUS_EVENT",
            onFriendStatus
        );

        context.log("Subscribed to FRIEND_STATUS_EVENT!");
    }

    private function onFriendStatus(event:Dynamic):Void {
        var friendId:UInt = cast Reflect.field(event, "mFriendId");

        context.log("Friend ID: " + Std.string(friendId));

        activityStore.recordActivities(friendId);
    }
}
