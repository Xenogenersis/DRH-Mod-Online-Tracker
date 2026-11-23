
package mods.online_tracker;

import mods.api.Context;
import mods.api.Mod;
import brain.stateMachine.State;
import brain.stateMachine.StateMachine;
import town.HomeState;
import distributedObjects.DistributedDungeonSummary;
import stateMachine.mainStateMachine.LoadingScreenState;
import town.SocialSubState;
import flash.text.TextField;
import brain.uI.UIButton;
import flash.display.MovieClip;
import flash.text.TextField;
import flash.display.DisplayObject;
import flash.display.DisplayObjectContainer;
import account.FriendInfo;
import flash.display.MovieClip;
import flash.text.TextFormat;
import flash.text.TextFormatAlign;
import flash.filters.GlowFilter;
import account.FriendInfo;
import openfl.events.Event;

class Main extends Mod {

    private var context:Context;
    private var activityStore:ActivityStore;
    private var currentSocial:Dynamic = null;
    private var frameCounter:Int = 0;
    private var currentPopulater:Dynamic = null;
    private var leastActiveButton:UIButton = null;
    private var leastActiveRoot:Dynamic = null;
    private var lastDisplayedPage:Int = -1;
    private var lastDisplayedPopulater:Dynamic = null;

    override public function init(context:Context):Void {

        this.context = context;

        activityStore = new ActivityStore(context);

        // Enter HomeState
        context.core.onStateEnter(function(machine:StateMachine, state:State) {

            if (Std.isOfType(state, HomeState)){
                var homeState:HomeState = cast state;
                var accountInfo = homeState.mDBFacade.dbAccountInfo;
                loadGifts(accountInfo);
                loadOnline(accountInfo);

                var checkGiftAlert = Reflect.field(homeState, "checkGiftAlert");
                if (checkGiftAlert != null) {
                    Reflect.callMethod(homeState, checkGiftAlert, []);
                }
            }

            // Enter LoadingScreenState
            if (Type.getClassName(Type.getClass(state)) == "stateMachine.mainStateMachine.LoadingScreenState"){
                var loadingState:LoadingScreenState = cast state;
                var accountInfo = loadingState.mDBFacade.dbAccountInfo;
                loadGifts(accountInfo);
                loadOnline(accountInfo);
            }

            if (Type.getClassName(Type.getClass(state)) == "town.SocialSubState") {
                currentSocial = state;
                frameCounter = 0;

                context.overlay.addEventListener(
                    openfl.events.Event.ENTER_FRAME,
                    updateListener
                );
            }
        });

        context.core.onStateExit(function(machine:StateMachine, state:State) {
            if (state == currentSocial) {
                var accountIds = getAllFriendIds(state);
                activityStore.removeMissingAccounts(accountIds);

                currentSocial = null;
                currentPopulater = null;
                leastActiveButton = null;
                leastActiveRoot = null;

                context.overlay.removeEventListener(
                    openfl.events.Event.ENTER_FRAME,
                    updateListener
                );

                lastDisplayedPage = -1;
                lastDisplayedPopulater = null;
            }
        });
    }

   private function loadGifts(accountInfo:Dynamic):Void {

    if (accountInfo == null) {
        context.log("ERROR: accountInfo is null!");
        return;
    }

    // Read the locally cached gifts
    var gifts:Dynamic = Reflect.getProperty(accountInfo, "gifts");

    if (gifts == null) {
        context.log("ERROR: gifts is null!");
        return;
    }

    var keysToArray = Reflect.field(gifts, "keysToArray");

    if (keysToArray == null) {
        context.log("ERROR: keysToArray is null!");
        return;
    }

    var itemFor = Reflect.field(gifts, "itemFor");

    if (itemFor == null) {
        context.log("ERROR: itemFor is null!");
        return;
    }

    var keys:Dynamic = Reflect.callMethod(gifts, keysToArray, []);

    if (keys == null) {
        context.log("ERROR: keys is null!");
        return;
    }

    var giftIds:Array<Dynamic> = [];
    var accountIds:Array<UInt> = [];

    for (key in keys) {
        var gift:Dynamic = Reflect.callMethod(gifts, itemFor, [key]);

        if (gift == null)
            continue;

        var requestId:String = Reflect.getProperty(gift, "mRequestId");
        var fromAccountId:UInt = Reflect.getProperty(gift, "mFromAccountId");

        if (requestId == null)
            continue;

        giftIds.push(requestId);
        accountIds.push(fromAccountId);

    }

    // Find new gifts
    var newGiftIds = activityStore.isNewGift(giftIds);

    // Save all currently available gift IDs
    activityStore.recordGifts(giftIds);

    // Save sender activities
    if (accountIds.length > 0)
        activityStore.recordActivities(accountIds);
}

    private function loadOnline(accountInfo:Dynamic):Void {
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

            if (friendInfo.isOnline()) {
                accountIds.push(accountId);
            }
        }

        if (accountIds.length > 0)
            activityStore.recordActivities(accountIds);
    }

    private function getFriendSelectField(populater:Dynamic):TextField {

        if (populater == null)
            return null;

        var mc:Dynamic = Reflect.field(populater, "mFriendPopulaterMC");

        if (mc == null) {
            context.log("mFriendPopulaterMC is null!");
            return null;
        }

        var options:Dynamic = mc.getChildByName("fm_selection_options");

        if (options == null) {
            context.log("fm_selection_options not found!");
            return null;
        }

        var selectField:Dynamic = options.getChildByName("txt_select");

        if (selectField == null) {
            context.log("txt_select not found!");
            return null;
        }

        return cast selectField;
    }

    private function createExtraButton(populater:Dynamic):UIButton {
        var mc:Dynamic = Reflect.field(populater, "mFriendPopulaterMC");
        var facade:Dynamic = Reflect.field(populater, "mDBFacade");
        var townStateMachine:Dynamic = Reflect.field(populater, "mTownStateMachine");

        if (mc == null || facade == null || townStateMachine == null) {
            context.log("FriendPopulater data is missing!");
            return null;
        }

        // Find the original selection options and button
        var options:Dynamic = mc.getChildByName("fm_selection_options");

        if (options == null) {
            context.log("Original selection options not found!");
            return null;
        }

        var original:Dynamic = options.getChildByName("button_all");

        if (original == null) {
            context.log("Original button not found!");
            return null;
        }

        // Create a second instance of the entire FriendPopulater asset
        var asset:Dynamic = townStateMachine.getTownAsset("friends_populater");

        if (asset == null) {
            context.log("FriendPopulater asset not found!");
            return null;
        }

        var tempMC:Dynamic = ASCompat.createInstance(asset, []);

        if (tempMC == null) {
            context.log("Failed to create temporary MovieClip!");
            return null;
        }

        // Find the selection options in the new instance
        var tempOptions:Dynamic = tempMC.getChildByName("fm_selection_options");

        if (tempOptions == null) {
            context.log("Temporary selection options not found!");
            return null;
        }

        // Get the second ALL button from the new instance
        var extraMC:Dynamic = tempOptions.getChildByName("button_all");

        if (extraMC == null) {
            context.log("Second button not found!");
            return null;
        }

        // Find the label
        var label:Dynamic = extraMC.getChildByName("label");

        if (label == null) {
            context.log("Label of the second button not found!");
            return null;
        }

        // Change the button label
        label.text = "LEAST ACTIVE";
        label.wordWrap = false;
        label.multiline = false;

        // Increase the button width
        var widthFactor:Float = 2.5;

        // Resize the text field and keep it centered
        var oldLabelWidth:Float = label.width;

        label.width = oldLabelWidth * widthFactor;
        label.x -= (label.width - oldLabelWidth) / 2;

        // Resize the backgrounds of the button states
        var states = ["up", "over", "disabled"];

        for (stateName in states) {
            var state:Dynamic = extraMC.getChildByName(stateName);

            if (state != null) {
                state.scaleX *= widthFactor;
            }
        }

        // Detach the button from the temporary MovieClip
        tempOptions.removeChild(extraMC);

        // Add it to the original selection options
        options.addChild(extraMC);

        // Position it next to the original ALL button
        extraMC.x = original.x + original.width + 10;
        extraMC.y = original.y;

        // Create an independent UIButton
        var button = new UIButton(cast facade, cast extraMC);

        return button;
    }

    private function selectLeastActive():Void {
        var accountIds = getAllFriendIds(currentSocial);

        if (accountIds == null || accountIds.length == 0)
            return;

        var selectedId = activityStore.getLeastActiveAccount(accountIds);

        if (selectedId == null)
            return;

        selectFriendById(selectedId);
    }

    private function selectFriendById(accountId:UInt):Void {
        if (currentSocial == null)
            return;

        var manager:Dynamic = Reflect.field(currentSocial, "mUIFriendManager");
        if (manager == null)
            return;

        var states:Dynamic = Reflect.field(manager, "states");
        var friends:Dynamic = states == null ? null : states.itemFor(1);
        if (friends == null)
            return;

        var populater:Dynamic = Reflect.field(friends, "mFriendPopulater");
        if (populater == null)
            return;

        var allFriends:Dynamic = Reflect.field(populater, "mListOfFriends");
        var selected:Dynamic = Reflect.field(populater, "mFriendsSelectedAcrossPages");

        if (allFriends == null || selected == null)
            return;

        // Clear the previous selection
        selected.clear();

        for (index in 0...allFriends.length) {
            var friend:FriendInfo = cast allFriends[index];

            if (friend != null && friend.id == accountId) {
                selected.add(index, true);
                break;
            }
        }
    }

    private function getAllFriendIds(state:State):Array<UInt> {
        var accountIds:Array<UInt> = [];

        var manager:Dynamic = Reflect.field(state, "mUIFriendManager");
        if (manager == null)
            return accountIds;

        var states:Dynamic = Reflect.field(manager, "states");
        var friends:Dynamic = states == null ? null : states.itemFor(1);
        if (friends == null)
            return accountIds;

        var populater:Dynamic = Reflect.field(friends, "mFriendPopulater");
        if (populater == null)
            return accountIds;

        var allFriends:Dynamic = Reflect.field(populater, "mListOfFriends");
        if (allFriends == null)
            return accountIds;

        for (friend in allFriends) {
            if (friend != null)
                accountIds.push(friend.id);
        }

        return accountIds;
    }

    var updateListener = function(event) {
        frameCounter++;

        if (frameCounter >= 15) {
            frameCounter = 0;
            updateFriendIds(event);
        }
    };

    private function updateFriendIds(event:Event):Void {
        if (!context.core.alive || currentSocial == null)
            return;

        var manager:Dynamic = Reflect.field(currentSocial, "mUIFriendManager");

        if (manager == null || manager.currentState != 1)
            return;

        var states:Dynamic = Reflect.field(manager, "states");
        var friends:Dynamic = states == null ? null : states.itemFor(1);

        if (friends == null)
            return;

        var populater:Dynamic = Reflect.field(friends, "mFriendPopulater");

        if (populater == null)
            return;

        var currentPage:Int = populater.mCurrentPage;

        if (populater != lastDisplayedPopulater || currentPage != lastDisplayedPage) {
            setDate(populater);

            lastDisplayedPopulater = populater;
            lastDisplayedPage = currentPage;
        }

        ensureLeastActiveButton(populater);
    }

    private function ensureLeastActiveButton(populater:Dynamic):Void {
        var mc:Dynamic = Reflect.field(populater, "mFriendPopulaterMC");

        if (mc == null)
            return;

        var options:Dynamic = mc.getChildByName("fm_selection_options");

        if (options == null)
            return;

        // The button is already present
        if (currentPopulater == populater &&
            leastActiveRoot != null &&
            leastActiveRoot.parent == options) {
            return;
        }

        var noneButton:Dynamic = Reflect.field(populater, "mSelectNoneButton");
        var allButton:Dynamic = Reflect.field(populater, "mSelectAllButton");

        var textField:TextField = getFriendSelectField(populater);

        if (noneButton == null || allButton == null || textField == null)
            return;

        var noneRoot:Dynamic = Reflect.field(noneButton, "mRoot");
        var allRoot:Dynamic = Reflect.field(allButton, "mRoot");

        if (noneRoot == null || allRoot == null)
            return;

        var extraButton:UIButton = createExtraButton(populater);

        if (extraButton == null)
            return;

        extraButton.releaseCallback = function():Void {
            selectLeastActive();
        };

        var extraRoot:Dynamic = Reflect.field(extraButton, "mRoot");

        if (extraRoot == null)
            return;

        noneRoot.x += 50;
        extraRoot.x -= 40;
        allRoot.x -= 70;
        textField.x -= 70;

        currentPopulater = populater;
        leastActiveButton = extraButton;
        leastActiveRoot = extraRoot;
    }

    private function setDate(populater:Dynamic):Void {
        var friends:Dynamic = Reflect.field(populater, "mListOfFriends");
        var slots:Dynamic = Reflect.field(populater, "mListOfFriendSlots");
        var page:Int = Reflect.field(populater, "mCurrentPage");

        if (friends == null || slots == null)
            return;

        for (slotIndex in 0...slots.length) {
            var friendIndex = page * 15 + slotIndex;

            if (friendIndex >= friends.length)
                break;

            var friend:Dynamic = friends[friendIndex];
            var slot:Dynamic = slots[slotIndex];

            if (friend == null || slot == null)
                continue;

            var accountId = Reflect.getProperty(friend, "id");

            if (accountId == null)
                continue;

            // Find the existing text field
            var idText:TextField = cast slot.getChildByName("gift_tracker_date");

            // Create it only if it does not already exist
            if (idText == null) {
                idText = new TextField();
                idText.name = "gift_tracker_date";

                idText.width = 127;
                idText.height = 20;
                idText.x = 60;
                idText.y = 110;

                var format = new TextFormat();
                format.color = 0x000000;
                format.size = 12;
                format.bold = true;

                idText.defaultTextFormat = format;
                idText.setTextFormat(format);

                idText.filters = [
                    new GlowFilter(0xFFFFFF, 1, 2, 2, 10, 1)
                ];

                idText.selectable = false;
                idText.mouseEnabled = false;

                slot.addChild(idText);
            }

            // Update the text
            idText.text = activityStore.getLastOnlineDate(accountId);
        }
    }
}
