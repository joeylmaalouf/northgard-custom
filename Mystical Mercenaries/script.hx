var relationMultiplier = 10;
var relationToHire = 8.0;
var relationPerIncrease = 2.0;
var hireCooldown = 120;

var homeZones = [225, 101, 97, 215, 179, 147, 242, 124];
var players : Array<{
	uid : Int,
	player : Player,
	homeZone : Zone,
	isDead : Bool,
	isHiring : Bool,
	isTargeting : Bool,
	hiredFaction : Faction,
	lastHireTime : Float
}> = [for (zoneId in homeZones) {
	uid: homeZones.indexOf(zoneId),
	player: getZone(zoneId).owner,
	homeZone: getZone(zoneId),
	isDead: false,
	isHiring: false,
	isTargeting: false,
	hiredFaction: null,
	lastHireTime: 0.0
}];

var neutrals : Array<{
	name : String,
	formatName : String,
	faction : Faction,
	unit : UnitKind,
	count : Int,
	homeZone : Zone,
	isDead: Bool,
	price : Int,
	resource : ResourceKind,
	hireNotes : String
}> = [
	{
		name: "Skrymir", formatName: "Giant", faction: getFaction("Giant"),
		unit: Unit.Giant, count: 1, homeZone: getZone(173),
		isDead: false, price: 250, resource: Resource.Food,
		hireNotes: "Slow but powerful, the [Giant]s are among the strongest warriors available for hire."
	},
	{
		name: "Fjolsvin", formatName: "Giant2", faction: getFaction("Giant2"),
		unit: Unit.Giant2, count: 1, homeZone: getZone(146),
		isDead: false, price: 250, resource: Resource.Food,
		hireNotes: "Slow but powerful, the [Giant2]s are among the strongest warriors available for hire."
	},
	{
		name: "Kobolds", formatName: "Kobold", faction: getFaction("Kobold"),
		unit: Unit.Kobold, count: 3, homeZone: getZone(170),
		isDead: false, price: 250, resource: Resource.Wood,
		hireNotes: "Considered pests by many, the [Kobold]s will leave a trail of their kind along their path."
	},
	{
		name: "Myrkalfar", formatName: "Myrkalfar", faction: getFaction("Myrkalfar"),
		unit: Unit.Myrkalfar, count: 2, homeZone: getZone(153),
		isDead: false, price: 250, resource: Resource.Money,
		hireNotes: "The devious [Myrkalfar]s will drain your enemy's resources for the duration of their attack."
	}
];


function saveState () {
	// we don't support saving and loading yet
}


function init () {
	if (state.time == 0) {
		onFirstLaunch();
	}
	onEachLaunch();
}


function onFirstLaunch () {
	// remove all existing victory conditions besides lore
	state.removeVictory(VictoryKind.VMilitary);
	state.removeVictory(VictoryKind.VFame);
	state.removeVictory(VictoryKind.VMoney);
	state.removeVictory(VictoryKind.VHelheim);
	state.removeVictory(VictoryKind.VOdinSword);
	state.removeVictory(VictoryKind.VYggdrasil);
	if (isHost()) {
		@sync for (currentPlayer in players) {
			// we'll reveal all of the neutrals at the start for quicker trading
			for (neutralFaction in neutrals) {
				currentPlayer.player.discoverZone(neutralFaction.homeZone);
			}

			if (!currentPlayer.player.isAI) {
				currentPlayer.player.objectives.add("victoryExplanation", "These lands are vast and mysterious, and the factions that live here are unlike any beings known to your clan! Maybe you can befriend them while you attempt to gain victory by researching the ancient lore found here?");
				// we'll want to show each player their own relationship progress with the neutrals
				for (neutralFaction in neutrals) {
					currentPlayer.player.objectives.add("progress" + neutralFaction.name, "Your relationship with the [" + neutralFaction.formatName + "]s:", { visible: true, showProgressBar: true, goalVal: 100 });
				}
				// we'll set up objectives for each (human) player to be able to select a neutral faction to hire and a fellow player to target,
				// but we won't show them until the right conditions are met
				currentPlayer.player.objectives.add(
					"hireExplanation",
					"For the right price, any neutral faction that considers you a good friend (" + relationToHire * relationMultiplier + "%) will attack your enemies! And they'll send even more units at " + ((relationToHire + relationPerIncrease) * relationMultiplier) + "%. They do, however, all share a cooldown.",
					{ visible: false, showProgressBar: true, goalVal: hireCooldown },
					{ name: "Hire a faction", action: "invokeHiring" }
				);
				for (neutralFaction in neutrals) {
					currentPlayer.player.objectives.add(
						"hire" + neutralFaction.name,
						"You can hire a group of [" + neutralFaction.formatName + "]s to attack an enemy clan for " + neutralFaction.price + " [" + neutralFaction.resource + "]! " + neutralFaction.hireNotes,
						{ visible: false },
						{ name: "Hire", action: "invokeHire" + neutralFaction.name }
					);
				}
				currentPlayer.player.objectives.add(
					"cancelHire",
					"You can also return to the main overview without hiring anyone.",
					{ visible: false },
					{ name: "Cancel", action: "invokeCancel" }
				);
				currentPlayer.player.objectives.add(
					"selectTarget",
					"Select the target of your attack:",
					{ visible: false }
				);
				for (otherPlayer in players) {
					if (otherPlayer.uid != currentPlayer.uid) {
						currentPlayer.player.objectives.add(
							"target" + otherPlayer.uid,
							"Player " + (otherPlayer.uid + 1) + ", " + otherPlayer.player.name,
							{ visible: false },
							{ name: "Attack " + otherPlayer.player.name, action: "invokeAttackPlayer" + otherPlayer.uid }
						);
					}
				}
				currentPlayer.player.objectives.add(
					"cancelTarget",
					"Never mind!",
					{ visible: false },
					{ name: "Cancel", action: "invokeCancel" }
				);
			}
		}
	}
}


function onEachLaunch () {
	// we don't support saving and loading yet
}


// Regular update is called every 0.5s
function regularUpdate (dt : Float) {
	if (isHost()) {
		// we'll keep track of defeated players so we don't let the others raid them
		@sync for (currentPlayer in players) {
			if (!currentPlayer.isDead && currentPlayer.homeZone.owner != currentPlayer.player) {
				currentPlayer.isDead = true;
			}
		}
		// we'll keep track of defeated factions so we don't let players hire them
		@sync for (neutralFaction in neutrals) {
			if (!neutralFaction.isDead && neutralFaction.homeZone.getUnit(neutralFaction.unit) == null) {
				neutralFaction.isDead = true;
			}
		}

		// we'll limit our objective updates to every second instead of every 0.5 seconds to ease up on the computing
		if (state.time % 1 < 0.1) {
			@sync for (currentPlayer in players) {
				if (!currentPlayer.player.isAI && !currentPlayer.isDead) {
					// determine whether we should show this player the overview set of objectives
					// and while we're here, update the relationship progress bars
					var showOverview = !currentPlayer.isHiring && !currentPlayer.isTargeting;
					currentPlayer.player.objectives.setVisible("victoryExplanation", showOverview);
					for (neutralFaction in neutrals) {
						if (!neutralFaction.isDead) {
							currentPlayer.player.objectives.setCurrentVal("progress" + neutralFaction.name, currentPlayer.player.getAlignment(neutralFaction.faction, false) * relationMultiplier);
						}
						currentPlayer.player.objectives.setVisible("progress" + neutralFaction.name, showOverview && !neutralFaction.isDead);
					}

					// determine whether we should show this player the hiring set of objectives
					// and while we're here, update the hire cooldown progress bar
					var anyWilling = false;
					for (neutralFaction in neutrals) {
						var thisWilling = false;
						if (!neutralFaction.isDead) {
							var factionRelation = currentPlayer.player.getAlignment(neutralFaction.faction, false);
							if (factionRelation >= relationToHire) {
								thisWilling = true;
								anyWilling = true;
							}
						}
						currentPlayer.player.objectives.setVisible("hire" + neutralFaction.name, currentPlayer.isHiring && thisWilling);
						// if the player can't afford to hire this faction, we'll still show the option but gray it out
						var canAfford = currentPlayer.player.getResource(neutralFaction.resource) >= neutralFaction.price;
						currentPlayer.player.objectives.setStatus("hire" + neutralFaction.name, canAfford ? OStatus.Empty : OStatus.Missed);
					}
					currentPlayer.player.objectives.setVisible("cancelHire", currentPlayer.isHiring && anyWilling);

					// we want to show the player their hiring cooldown
					var timeSinceHire = toInt(state.time - currentPlayer.lastHireTime);
					if (timeSinceHire <= hireCooldown) {
						currentPlayer.player.objectives.setCurrentVal("hireExplanation", timeSinceHire);
					}
					// we only want to show the explanation and let them get further into hiring
					// if we're on the main menu and any of the factions are willing to be hired
					currentPlayer.player.objectives.setVisible("hireExplanation", showOverview && anyWilling);
					// if the player's hiring cooldown has not yet completed, we'll still show the explanation but gray it out
					var offCooldown = timeSinceHire >= hireCooldown;
					currentPlayer.player.objectives.setStatus("hireExplanation", offCooldown ? OStatus.Empty : OStatus.Missed);

					// determine whether we should show this player the targeting set of objectives
					for (otherPlayer in players) {
						currentPlayer.player.objectives.setVisible("selectTarget", currentPlayer.isTargeting);
						if (otherPlayer.uid != currentPlayer.uid) {
							currentPlayer.player.objectives.setVisible("target" + otherPlayer.uid, currentPlayer.isTargeting && !otherPlayer.isDead);
						}
						currentPlayer.player.objectives.setVisible("cancelTarget", currentPlayer.isTargeting);
					}
				}
			}
		}
	}
}


// oh how I wish we could pass args to the objective button callbacks
function invokeHiring () { var args : Array<Dynamic> = []; args.push(me()); invokeHost("startHiring", args); }
function invokeHireSkrymir () { var args : Array<Dynamic> = []; args.push(me()); args.push("Skrymir"); invokeHost("hireFaction", args); }
function invokeHireFjolsvin () { var args : Array<Dynamic> = []; args.push(me()); args.push("Fjolsvin"); invokeHost("hireFaction", args); }
function invokeHireKobolds () { var args : Array<Dynamic> = []; args.push(me()); args.push("Kobolds"); invokeHost("hireFaction", args); }
function invokeHireMyrkalfar () { var args : Array<Dynamic> = []; args.push(me()); args.push("Myrkalfar"); invokeHost("hireFaction", args); }
function invokeAttackPlayer0 () { var args : Array<Dynamic> = []; args.push(me()); args.push(0); invokeHost("orderAttack", args); }
function invokeAttackPlayer1 () { var args : Array<Dynamic> = []; args.push(me()); args.push(1); invokeHost("orderAttack", args); }
function invokeAttackPlayer2 () { var args : Array<Dynamic> = []; args.push(me()); args.push(2); invokeHost("orderAttack", args); }
function invokeAttackPlayer3 () { var args : Array<Dynamic> = []; args.push(me()); args.push(3); invokeHost("orderAttack", args); }
function invokeAttackPlayer4 () { var args : Array<Dynamic> = []; args.push(me()); args.push(4); invokeHost("orderAttack", args); }
function invokeAttackPlayer5 () { var args : Array<Dynamic> = []; args.push(me()); args.push(5); invokeHost("orderAttack", args); }
function invokeAttackPlayer6 () { var args : Array<Dynamic> = []; args.push(me()); args.push(6); invokeHost("orderAttack", args); }
function invokeAttackPlayer7 () { var args : Array<Dynamic> = []; args.push(me()); args.push(7); invokeHost("orderAttack", args); }
function invokeCancel () { var args : Array<Dynamic> = []; args.push(me()); args.push(null); invokeHost("hireFaction", args); }


function startHiring (playerRef : Player) {
	for (currentPlayer in players) {
		if (currentPlayer.player == playerRef) {
			currentPlayer.isHiring = true;
			break;
		}
	}
}


function hireFaction (playerRef : Player, factionName : String) {
	var hiredFaction = null;
	for (neutralFaction in neutrals) {
		if (neutralFaction.name == factionName) {
			hiredFaction = neutralFaction;
			break;
		}
	}
	for (currentPlayer in players) {
		if (currentPlayer.player == playerRef) {
			currentPlayer.isHiring = false;
			if (hiredFaction == null) {
				currentPlayer.isTargeting = false;
				currentPlayer.hiredFaction = null;
			}
			else {
				currentPlayer.isTargeting = true;
				currentPlayer.hiredFaction = hiredFaction.faction;
			}
			break;
		}
	}
}


function orderAttack (playerRef : Player, targetUid : Int) {
	var hiringPlayer = null;
	var targetPlayer = null;
	var hiredFaction = null;
	var hiredUnits = null;
	var attackSent = null;
	for (currentPlayer in players) {
		if (currentPlayer.player == playerRef) {
			hiringPlayer = currentPlayer;
		}
		if (currentPlayer.uid == targetUid) {
			targetPlayer = currentPlayer;
		}
	}
	for (neutralFaction in neutrals) {
		if (neutralFaction.faction == hiringPlayer.hiredFaction) {
			hiredFaction = neutralFaction;
			break;
		}
	}
	if (hiredFaction != null) {
		var factionRelation = hiringPlayer.player.getAlignment(hiredFaction.faction, false);
		// we'll send more units based on how far beyond the minimum relationship threshold the hiring player is with the hired faction
		var bonusGroups = toInt((factionRelation - relationToHire) / relationPerIncrease);
		// we'll spawn the neutral faction units in their home zone and attempt to path them to the target player
		hiredUnits = hiredFaction.homeZone.addUnit(hiredFaction.unit, hiredFaction.count * (1 + bonusGroups), null, false);
		attackSent = launchAttackPlayer(hiredUnits, targetPlayer.player);
	}
	for (currentPlayer in players) {
		if (currentPlayer.uid == hiringPlayer.uid) {
			currentPlayer.isTargeting = false;
			currentPlayer.hiredFaction = null;
			if (attackSent == true) {
				// if the attack worked, we'll take the payment and put the hiring player on cooldown
				currentPlayer.player.addResource(hiredFaction.resource, -hiredFaction.price);
				currentPlayer.lastHireTime = state.time;
				// we'll also give the hiring player a notification to let them track their attack
				var args : Array<Dynamic> = [];
				args.push("You've sent " + hiredUnits.length + " [" + hiredFaction.formatName + "]s to attack " + targetPlayer.player.name + "!");
				args.push(hiredUnits[0]);
				invoke(currentPlayer.player, "displayNotification", args);
				// and we'll the notify target player that they're being attacked
				args = [];
				args.push("Someone has hired the [" + hiredFaction.formatName + "]s to attack you!");
				args.push(hiredUnits[0]);
				invoke(targetPlayer.player, "displayNotification", args);
			}
			else if (attackSent == false) {
				// if the units failed to find a path to the target player, we'll kill them and notify the hiring player
				for (hiredUnit in hiredUnits) {
					hiredUnit.die(true, false);
				}
				var args : Array<Dynamic> = [];
				args.push("Your hired [" + hiredFaction.formatName + "]s failed to find a route to their target, so no attack has been sent.");
				args.push(null);
				invoke(currentPlayer.player, "displayNotification", args);
			}
			// if attackSent is neither true nor false, then we had no faction and thus didn't attempt an attack at all, so no further cleanup is needed
			break;
		}
	}
}


function displayNotification (message : String, target : Entity) {
	// genericNotify doesn't always work when the player reference is not me(),
	// so we're invoking this function on each player's client as needed
	me().genericNotify(message, target);
}
