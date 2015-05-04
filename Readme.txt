INeed

This addon is a shopping list, item fulfillment addon.

Idea:
The initial idea here was to track items that a player 'needs' for one reason or another,
that is not already tracked elsewhere.

Problem to solve:
Some professions need many items to craft a single item. Some of those items may take days to gather.
This would let someone create a shopping list of items that are needed.

Show which of your alts need how many of that item (tooltip).

Some items are vendor sold, and this will try to purchase the needed items when available for sale.
(This will be an option, possibly setting a max purchase price)
(Something like a spending account could also be setup for this. IE, give INeed 10G, as soon as it spends 10G
  for items, it will only alert the user that it found an item for sale, but will not purchase. This would be
  turned off by simply setting this to 0G, setting it to a negative value would make it unlimited -- if desired)



The interface is: "INeed <this item> <quantity>"
/ineed <itemLink>       -- needs 1 of item
/ineed <itemLink> 120   -- needs 120 of item
/ineed <itemLink> 0     -- needs 0 of item (will clear tracking)
/ineed item:9999        -- can be used instead of actual link (for scripting)
/ineed list             -- shows a list of needed items
/ineed account          -- shows the remaining amount in the spending account
/ineed account 0        -- sets the account to 0, turning off auto purchase
/ineed account 10000    -- sets account to 1 Gold
/ineed account 1g       -- sets account to 1 Gold
/ineed account 1g20s5c  -- sets account to 1 Gold, 20 Silver, and 5 Copper
/ineed remove <charName>-<realmName> -- removes tracking of all items for a specific character

Goals:
* Easy to start tracking items
* Show info with the item (tooltip)
* Show tracking info
* An alert once the goal for an item has been reached.
* The ability to see a shopping list of items
* An alert to a player logging that another character needs something in your inv


Versions:
0.10    Crontab feature scrapped.
        Create a "toMake" field for items made from an enchant(profession)
        -- not listed in fulfillment list
        -- not affected by current amount
        -- "toMake" decremented when items made
        -- success is to decrement "toMake" to 0
0.09    List panel to show needed items
        Option to open next to profession tab when something needed can be crafted.
0.08    Adding crontab like syntax for repeat -- Removing to a different addon
0.07    Adding tracking of currencies.  /in currency:###  -- incomplete for now
0.06    Needing a number of items less than the number already have does not track item.
        Fixed a bug around not getting an item link when the item is addded with item:#### and item not in cache
0.05    Timestamp of when item added.
        Delete a char "/in remove <name>-<rname>
        Nice options panel.
0.04	Account bug found and fixed.
		Can now use "account +value" to add a value, or "account -value" to remove a value
		^^^ Good for adding sum from vendor trash selling, or setting up a daily allowance
0.03	Putting progress announements to UIErrorFrame
0.02	Adding in spending account.
		adding item via item:9999 working
		Also hacked together a unittesting frame work

0.01	Initial work, command line works, tracking works, alert message on fulfilment, auto purchase


ToDO:
* Create a longer term shopping list sort of panel
    -- [ICON] 5/10 Item
^^^ Open next to Mail panel

* Record and separate player's faction (no cross faction mail)
* Add an "IN BAGS" step to fulfillment.

* Recipe links:
    -- http://www.wowwiki.com/API_GetTradeSkillNumReagents
    -- http://www.wowwiki.com/API_GetTradeSkillRecipeLink
    -- http://www.wowwiki.com/EnchantLink
    |cffffffff|Henchant:20024|h[Enchant Boots - Spirit]|h|r
    |cffffffff|Henchant:44157|h[Engineering: Turbo-Charged Flying Machine]|h|r
    local found, _, enchantString = string.find(enchantLink, "^|%x+|H(.+)|h%[.+%]")
    ---
    local numReagents = GetTradeSkillNumReagents(id);
    local totalReagents = 0;
    for i=1, numReagents, 1 do
      local reagentName, reagentTexture, reagentCount, playerReagentCount = GetTradeSkillReagentInfo(id, i);
      totalReagents = totalReagents   reagentCount;
    end;
    ---

    Does not set needed for the item to be made, sets toMake
    ^- Need to redo:
        * Add code to set toMake
        * Update code (decrimate toMake on make)
        ^- Need To Make: 10 (-5)
        ^- Need To Make: 5 (-5)
        * Removing needed does not remove entry
        * Won't show up on the fulfillment lists
        * Should still be able to 'need' a number of the item.
        ^- (I need to make 10, but I need 20)
        ^- (you already have 10?)
    ** Research how to determine if an item is 'made', API call, event, etc.

* Options panel
    -- Account value - editable
    --


http://wowprogramming.com/utils/xmlbrowser/live/FrameXML/OptionsPanelTemplates.xml

----------------
Global totals
----------------
This should allow the addon to show progress for items needed by other characters.
-- Note:  No mailboxes in the Pandarian start zone, so ignore any item needed by a character that does not have a faction.

For an item you need, only show your progress.
10 / 15 (+1) [Special Item]
-- Signal complete

For an item that you do not need, show global progress.
10 / 20 (+1) [Special Item]
-- Signal complete here too.
(Note: as of now, if you need 10, and everyone else needs 10, it will track your 10 and self-clear your need, and start tracking others. /sad)


(Do I want to change the addon to continue to track the item if others still need it too?)
(How to keep a character from giving away items that you need, but have completed, yet you continue to gather?)

-- Ideas?
* What is the usage of this addon?
    -- Self, Gathering goal (daily material requirements - 180 ghost ore)
    -- Self, crafting recipie (need 5x, 5y, and 15z to craft 5a) - need on all (see feature to make these crafting goals)
    -- Self, autopurchase (need 5 x, vendor sells, autopurchase)
    -- Self, pre-plan for which gear I 'need' from a dungeon, or raid, or from a token.
       ^^ See reminder that you need(ed) it, to allow you to roll need
    -- Self, currency cannot be traded, so no global fulfillment here, just tracking for a goal
       ^^ Archelogy - can complete a puzzle, or do a daily gathering (quest?)
       ^^ Item Upgrades need an amount to upgrade with.
    -- Others, Steve needs 5x, I don't need x, I just got 2x, send them to Steve
    -- Others, Steve needs 5x, I have 5x in my bank, send to Steve
    -- Others, Steve needs [account bound gear], show that I now have it, and send it to Steve
    -- Others, Steve and Sally need 5x and 10x of an item, try to gather 15x for them.
    -- Self and Others, I and Steve need 5x and 5x of this item.

* if others need an item too, don't clear your goal, set it as fulfilled, show total needed?
* Need to filter based on BoE, Soulbound, or BoA.

