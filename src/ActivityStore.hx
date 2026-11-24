package mods.online_tracker;

import haxe.Json;
import sys.io.File;
import sys.FileSystem;
import mods.api.Context;

private typedef ActivityEntry = {
    var accountId:String;
    var date:String;
}

class ActivityStore {

    private var filePath:String;
    private var lastOnlineDates:List<ActivityEntry>;
    private var context:Context;
    private var entriesById:Map<String, ActivityEntry>;
    private var knownGiftIds:Map<String, Bool>;

    public function new(context:Context) {
        this.context = context;
        filePath = context.data + "/activity_history.json";
        lastOnlineDates = new List<ActivityEntry>();
        entriesById = new Map<String, ActivityEntry>();
        knownGiftIds = new Map<String, Bool>();

        load();
    }

    // Insert or update an entry while maintaining sorted order
    private function insertSorted(accountId:String, date:String):Void {
        var existing = entriesById.get(accountId);

        if (existing != null) {
            existing.date = date;
            return;
        }

        var newId = Std.parseInt(accountId);

        var newEntry:ActivityEntry = {
            accountId: accountId,
            date: date
        };

        var remaining = new List<ActivityEntry>();
        var inserted = false;

        for (current in lastOnlineDates) {
            if (!inserted && Std.parseInt(current.accountId) > newId) {
                remaining.add(newEntry);
                inserted = true;
            }

            remaining.add(current);
        }

        if (!inserted)
            remaining.add(newEntry);

        lastOnlineDates = remaining;
        entriesById.set(accountId, newEntry);
    }

    // Find an entry by account ID
    private function findEntry(accountId:String):Null<ActivityEntry> {
        return entriesById.get(accountId);
    }

    // Load saved data
    private function load():Void {
        if (!FileSystem.exists(filePath)) {
            context.log("Activity history file does not exist!");
            return;
        }

        var content = File.getContent(filePath);
        var data:Dynamic = Json.parse(content);

        var activities:Dynamic = Reflect.field(data, "activity");

        if (activities != null) {
            var entries:Array<ActivityEntry> = [];

            for (accountId in Reflect.fields(activities)) {
                var entry:ActivityEntry = {
                    accountId: accountId,
                    date: Reflect.field(activities, accountId)
                };

                entries.push(entry);
                entriesById.set(accountId, entry);
            }

            entries.sort(function(a, b) {
                var idA = Std.parseInt(a.accountId);
                var idB = Std.parseInt(b.accountId);

                return idA < idB ? -1 : (idA > idB ? 1 : 0);
            });

            for (entry in entries)
                lastOnlineDates.add(entry);
        }

        var gifts:Dynamic = Reflect.field(data, "gifts");

        if (gifts != null) {
            for (giftId in gifts) {
                knownGiftIds.set(Std.string(giftId), true);
            }
        }
    }

    // Record last online date
    public function recordActivities(accountIds:Array<UInt>):Void {
        var date = Date.now().toString();

        for (accountId in accountIds) {
            var id = Std.string(accountId);
            insertSorted(id, date);
        }

        save();
    }

    // Save data to JSON
    private function save():Void {
        var activities:Dynamic = {};

        for (entry in lastOnlineDates) {
            Reflect.setField(activities, entry.accountId, entry.date);
        }

        var gifts:Array<String> = [];

        for (giftId in knownGiftIds.keys()) {
            gifts.push(giftId);
        }

        var data = {
            activity: activities,
            gifts: gifts
        };

        File.saveContent(filePath, Json.stringify(data, null, "  "));
    }

    // Get last online date
    public function getLastOnlineDate(accountId:Dynamic):String {
        var entry = findEntry(Std.string(accountId));

        if (entry != null)
            return entry.date.split(" ")[0];

        return "\u00A0\u00A0\u00A0\u00A0Never";
    }

    // Remove account activity
    public function removeMissingAccounts(accountIds:Array<UInt>):Void {
        accountIds.sort(function(a, b) {
            return a < b ? -1 : (a > b ? 1 : 0);
        });

        var remaining = new List<ActivityEntry>();
        var newIndex = new Map<String, ActivityEntry>();
        var i = 0;

        for (entry in lastOnlineDates) {
            var entryId = Std.parseInt(entry.accountId);

            while (i < accountIds.length && accountIds[i] < entryId) {
                i++;
            }

            if (i < accountIds.length && accountIds[i] == entryId) {
                remaining.add(entry);
                newIndex.set(entry.accountId, entry);
            }
        }

        if (remaining.length != lastOnlineDates.length) {
            lastOnlineDates = remaining;
            entriesById = newIndex;
            save();
        }
    }

    // Get least active account
   public function getLeastActiveAccount(accountIds:Array<UInt>):Null<UInt> {
        if (accountIds == null || accountIds.length == 0)
            return null;

        accountIds.sort(function(a, b) {
            return a < b ? -1 : (a > b ? 1 : 0);
        });

        var missingIds:Array<UInt> = [];
        var oldestId:UInt = 0;
        var oldestDate:Float = Math.POSITIVE_INFINITY;

        var entryIterator = lastOnlineDates.iterator();
        var entry:ActivityEntry = entryIterator.hasNext() ? entryIterator.next() : null;

        for (accountId in accountIds) {
            while (entry != null && Std.parseInt(entry.accountId) < accountId) {
                entry = entryIterator.hasNext() ? entryIterator.next() : null;
            }

            if (entry == null || Std.parseInt(entry.accountId) != accountId) {
                missingIds.push(accountId);
                continue;
            }

            var timestamp = Date.fromString(entry.date).getTime();

            if (timestamp < oldestDate) {
                oldestDate = timestamp;
                oldestId = accountId;
            }
        }

        if (missingIds.length > 0)
            return missingIds[Std.random(missingIds.length)];

        return oldestId;
    }

    public function getAllGiftIds():Array<String> {
        var giftIds:Array<String> = [];

        for (giftId in knownGiftIds.keys()) {
            giftIds.push(giftId);
        }

        return giftIds;
    }


    public function syncGifts(giftIds:Array<Dynamic>):Void {
        var currentGiftIds = new Map<String, Bool>();

        // Alle aktuell vorhandenen Gifts merken
        for (giftId in giftIds) {
            currentGiftIds.set(Std.string(giftId), true);
        }

        // Alte Gifts entfernen, die nicht mehr vorhanden sind
        for (giftId in knownGiftIds.keys()) {
            if (!currentGiftIds.exists(giftId)) {
                knownGiftIds.remove(giftId);
            }
        }

        // Aktuellen Bestand übernehmen
        for (giftId in currentGiftIds.keys()) {
            knownGiftIds.set(giftId, true);
        }

        save();
    }
}
