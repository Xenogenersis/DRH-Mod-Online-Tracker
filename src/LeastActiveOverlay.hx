
package mods.online_tracker;

import mods.api.Context;

import brain.stateMachine.State;
import brain.uI.UIButton;

import flash.text.TextField;
import flash.text.TextFormat;
import flash.filters.GlowFilter;

import openfl.events.Event;

import account.FriendInfo;

class LeastActiveOverlay {

    private var context:Context;
    private var activityStore:ActivityStore;

    private var currentSocial:State = null;
    private var frameCounter:Int = 0;

    private var currentPopulater:Dynamic = null;
    private var leastActiveButton:UIButton = null;
    private var leastActiveRoot:Dynamic = null;

    private var lastDisplayedPage:Int = -1;
    private var lastDisplayedPopulater:Dynamic = null;

    public function new(context:Context, activityStore:ActivityStore) {
        this.context = context;
        this.activityStore = activityStore;
    }

    // --------------------------------
    // Start and stop overlay updates
    // --------------------------------

    public function start(state:State):Void {
        currentSocial = state;
        frameCounter = 0;

        context.overlay.addEventListener(Event.ENTER_FRAME, updateListener);
    }

    public function stop():Void {
        context.overlay.removeEventListener(
            Event.ENTER_FRAME,
            updateListener
        );

        currentSocial = null;
        frameCounter = 0;

        currentPopulater = null;
        leastActiveButton = null;
        leastActiveRoot = null;

        lastDisplayedPage = -1;
        lastDisplayedPopulater = null;
    }

    private var updateListener = function(event:Event):Void {
        frameCounter++;

        if (frameCounter >= 15) {
            frameCounter = 0;
            updateFriendIds();
        }
    };

    // --------------------------------
    // Update friend list information
    // --------------------------------

    private function updateFriendIds():Void {
        if (!context.core.alive || currentSocial == null) {
            return;
        }

        var manager:Dynamic = Reflect.field(
            currentSocial,
            "mUIFriendManager"
        );

        if (manager == null || manager.currentState != 1) {
            return;
        }

        var states:Dynamic = Reflect.field(manager, "states");
        var friends:Dynamic = states == null ? null : states.itemFor(1);

        if (friends == null) {
            return;
        }

        var populater:Dynamic = Reflect.field(
            friends,
            "mFriendPopulater"
        );

        if (populater == null) {
            return;
        }

        var currentPage:Int = populater.mCurrentPage;

        if (
            populater != lastDisplayedPopulater ||
            currentPage != lastDisplayedPage
        ) {
            setDate(populater);

            lastDisplayedPopulater = populater;
            lastDisplayedPage = currentPage;
        }

        ensureLeastActiveButton(populater);
    }

    // --------------------------------
    // Select the friend with the lowest activity
    // --------------------------------

    private function selectLeastActive():Void {
        if (currentSocial == null) {
            return;
        }

        var accountIds = getAllFriendIds(currentSocial);

        if (accountIds == null || accountIds.length == 0) {
            return;
        }

        var selectedId = activityStore.getLeastActiveAccount(accountIds);

        if (selectedId == null) {
            return;
        }

        selectFriendById(currentSocial, selectedId);
    }

    private function getAllFriendIds(state:State):Array<UInt> {
        var manager:Dynamic = Reflect.field(
            state,
            "mUIFriendManager"
        );

        if (manager == null) {
            return [];
        }

        var states:Dynamic = Reflect.field(manager, "states");
        var friends:Dynamic = states == null ? null : states.itemFor(1);

        if (friends == null) {
            return [];
        }

        var populater:Dynamic = Reflect.field(
            friends,
            "mFriendPopulater"
        );

        if (populater == null) {
            return [];
        }

        var allFriends:Dynamic = Reflect.field(
            populater,
            "mListOfFriends"
        );

        if (allFriends == null) {
            return [];
        }

        var accountIds:Array<UInt> = [];

        for (friend in allFriends) {
            if (friend != null) {
                accountIds.push(friend.id);
            }
        }

        return accountIds;
    }

    private function selectFriendById(
        state:State,
        accountId:UInt
    ):Void {
        if (state == null) {
            return;
        }

        var manager:Dynamic = Reflect.field(
            state,
            "mUIFriendManager"
        );

        if (manager == null) {
            return;
        }

        var states:Dynamic = Reflect.field(manager, "states");
        var friends:Dynamic = states == null ? null : states.itemFor(1);

        if (friends == null) {
            return;
        }

        var populater:Dynamic = Reflect.field(
            friends,
            "mFriendPopulater"
        );

        if (populater == null) {
            return;
        }

        var allFriends:Dynamic = Reflect.field(
            populater,
            "mListOfFriends"
        );

        var selected:Dynamic = Reflect.field(
            populater,
            "mFriendsSelectedAcrossPages"
        );

        if (allFriends == null || selected == null) {
            return;
        }

        selected.clear();

        for (index in 0...allFriends.length) {
            var friend:FriendInfo = cast allFriends[index];

            if (friend != null && friend.id == accountId) {
                selected.add(index, true);
                break;
            }
        }
    }

    // --------------------------------
    // Create and manage the overlay button
    // --------------------------------

    private function ensureLeastActiveButton(populater:Dynamic):Void {
        var mc:Dynamic = Reflect.field(
            populater,
            "mFriendPopulaterMC"
        );

        if (mc == null) {
            return;
        }

        var options:Dynamic = mc.getChildByName(
            "fm_selection_options"
        );

        if (options == null) {
            return;
        }

        if (
            currentPopulater == populater &&
            leastActiveRoot != null &&
            leastActiveRoot.parent == options
        ) {
            return;
        }

        var noneButton:Dynamic = Reflect.field(
            populater,
            "mSelectNoneButton"
        );

        var allButton:Dynamic = Reflect.field(
            populater,
            "mSelectAllButton"
        );

        var textField:TextField = getFriendSelectField(populater);

        if (noneButton == null || allButton == null || textField == null) {
            return;
        }

        var noneRoot:Dynamic = Reflect.field(noneButton, "mRoot");
        var allRoot:Dynamic = Reflect.field(allButton, "mRoot");

        if (noneRoot == null || allRoot == null) {
            return;
        }

        var extraButton:UIButton = createExtraButton(populater);

        if (extraButton == null) {
            return;
        }

        extraButton.releaseCallback = function():Void {
            selectLeastActive();
        };

        var extraRoot:Dynamic = Reflect.field(extraButton, "mRoot");

        if (extraRoot == null) {
            return;
        }

        noneRoot.x += 50;
        extraRoot.x -= 40;
        allRoot.x -= 70;
        textField.x -= 70;

        currentPopulater = populater;
        leastActiveButton = extraButton;
        leastActiveRoot = extraRoot;
    }

    private function getFriendSelectField(
        populater:Dynamic
    ):TextField {
        if (populater == null) {
            return null;
        }

        var mc:Dynamic = Reflect.field(
            populater,
            "mFriendPopulaterMC"
        );

        if (mc == null) {
            return null;
        }

        var options:Dynamic = mc.getChildByName(
            "fm_selection_options"
        );

        if (options == null) {
            return null;
        }

        return cast options.getChildByName("txt_select");
    }

    private function createExtraButton(populater:Dynamic):UIButton {
        var mc:Dynamic = Reflect.field(
            populater,
            "mFriendPopulaterMC"
        );

        var facade:Dynamic = Reflect.field(
            populater,
            "mDBFacade"
        );

        var townStateMachine:Dynamic = Reflect.field(
            populater,
            "mTownStateMachine"
        );

        if (mc == null || facade == null || townStateMachine == null) {
            return null;
        }

        var options:Dynamic = mc.getChildByName(
            "fm_selection_options"
        );

        if (options == null) {
            return null;
        }

        var original:Dynamic = options.getChildByName("button_all");

        if (original == null) {
            return null;
        }

        var asset:Dynamic = townStateMachine.getTownAsset(
            "friends_populater"
        );

        if (asset == null) {
            return null;
        }

        var tempMC:Dynamic = ASCompat.createInstance(asset, []);

        if (tempMC == null) {
            return null;
        }

        var tempOptions:Dynamic = tempMC.getChildByName(
            "fm_selection_options"
        );

        if (tempOptions == null) {
            return null;
        }

        var extraMC:Dynamic = tempOptions.getChildByName(
            "button_all"
        );

        if (extraMC == null) {
            return null;
        }

        var label:Dynamic = extraMC.getChildByName("label");

        if (label == null) {
            return null;
        }

        label.text = "LEAST ACTIVE";
        label.wordWrap = false;
        label.multiline = false;

        var widthFactor:Float = 2.5;
        var oldLabelWidth:Float = label.width;

        label.width = oldLabelWidth * widthFactor;
        label.x -= (label.width - oldLabelWidth) / 2;

        var states = ["up", "over", "disabled"];

        for (stateName in states) {
            var buttonState:Dynamic = extraMC.getChildByName(stateName);

            if (buttonState != null) {
                buttonState.scaleX *= widthFactor;
            }
        }

        tempOptions.removeChild(extraMC);
        options.addChild(extraMC);

        extraMC.x = original.x + original.width + 10;
        extraMC.y = original.y;

        return new UIButton(cast facade, cast extraMC);
    }

    // --------------------------------
    // Display activity dates in the friend list
    // --------------------------------

    private function setDate(populater:Dynamic):Void {
        var friends:Dynamic = Reflect.field(
            populater,
            "mListOfFriends"
        );

        var slots:Dynamic = Reflect.field(
            populater,
            "mListOfFriendSlots"
        );

        var page:Int = Reflect.field(
            populater,
            "mCurrentPage"
        );

        if (friends == null || slots == null) {
            return;
        }

        for (slotIndex in 0...slots.length) {
            var friendIndex = page * 15 + slotIndex;

            if (friendIndex >= friends.length) {
                break;
            }

            var friend:Dynamic = friends[friendIndex];
            var slot:Dynamic = slots[slotIndex];

            if (friend == null || slot == null) {
                continue;
            }

            var accountId = Reflect.getProperty(friend, "id");

            if (accountId == null) {
                continue;
            }

            var idText:TextField = cast slot.getChildByName(
                "gift_tracker_date"
            );

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

            idText.text = activityStore.getLastOnlineDate(accountId);
        }
    }
}
