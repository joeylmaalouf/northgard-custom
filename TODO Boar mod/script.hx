var homeZones = [225, 101, 97, 215, 179, 147, 242, 124];
var players : Array<{
	uid : Int,
	player : Player,
	homeZone : Zone,
	isDead : Bool,
	hiring : Faction
}> = [for (zoneId in homeZones) {
	uid: homeZones.indexOf(zoneId),
	player: getZone(zoneId).owner,
	homeZone: getZone(zoneId),
	isDead: false,
	hiring: null
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
	resource : ResourceKind
}> = [
	{
		name: "Jotnar", formatName: "Giant", faction: getFaction("Giant"),
		unit: Unit.Giant, count: 1, homeZone: getZone(170),
		isDead: false, price: 300, resource: Resource.Food
	},
	{
		name: "Kobolds", formatName: "Kobold", faction: getFaction("Kobold"),
		unit: Unit.Kobold, count: 4, homeZone: getZone(153),
		isDead: false, price: 300, resource: Resource.Wood
	},
	{
		name: "Myrkalfar", formatName: "Myrkalfar", faction: getFaction("Myrkalfar"),
		unit: Unit.Myrkalfar, count: 2, homeZone: getZone(146),
		isDead: false, price: 300, resource: Resource.Money
	}
];
var relationMultiplier = 10;
var jotnarRelationCap = 9.5; // TODO: 9.9
var relationToHire = 7.5;
var relationPerIncrease = 1.0;


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
		for (currentPlayer in players) {
			currentPlayer.player.addResource(Resource.Lore, 180, false); // TODO: remove, and change cdb back to 1/1/2 instead of 10/10/20, and remove red extra starting buildings
			// we'll reveal all of the neutrals at the start for quicker trading
			for (neutralFaction in neutrals) {
				currentPlayer.player.discoverZone(neutralFaction.homeZone);
			}

			if (!currentPlayer.player.isAI) {
				currentPlayer.player.objectives.add("victoryExplanation", "These lands are vast and mysterious, and the factions that live here are unlike any beings known to your clan! Maybe you can befriend them while you attempt to gain victory by researching the ancient lore found here?");
				// we'll want to show each player their own relationship progress with the neutrals
				currentPlayer.player.objectives.add("progressJotnar", "Your relationship with the [Giant]s (note that this maxes out at " + jotnarRelationCap * relationMultiplier + "%, not 100%, to prevent them from allying with just one faction):", { visible: true, showProgressBar: true, goalVal: 100 });
				currentPlayer.player.objectives.add("progressKobolds", "Your relationship with the [Kobold]s:", { visible: true, showProgressBar: true, goalVal: 100 });
				currentPlayer.player.objectives.add("progressMyrkalfar", "Your relationship with the [Myrkalfar]s:", { visible: true, showProgressBar: true, goalVal: 100 });
				// we'll set up objectives for each (human) player to be able to select a neutral faction to hire and a fellow player to target,
				// but we won't show them until the right conditions are met
				currentPlayer.player.objectives.add(
					"hireExplanation",
					"For the right price, any neutral faction that considers you a friend (75%) will attack your enemies! The better your relationship, the more units they'll send (every 10%)!",
					{ visible: false }
				);
				for (neutralFaction in neutrals) {
					currentPlayer.player.objectives.add(
						"hire" + neutralFaction.name,
						// "Send a group of [" + neutralFaction.formatName + "]s to attack an enemy clan for " + neutralFaction.price + " [" + neutralFaction.resource + "]!",
						"You can hire [" + neutralFaction.formatName + "]s for " + neutralFaction.price + " [" + neutralFaction.resource + "]!",
						{ visible: false },
						{ name: "Hire", action: "invokeHire" + neutralFaction.name }
					);
				}
				currentPlayer.player.objectives.add(
					"selectTarget",
					"Select the target of your attack:",
					{ visible: false }
				);
				for (otherPlayer in players) {
					if (otherPlayer.player != currentPlayer.player) {
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
					"nobody at all",
					{ visible: false },
					{ name: "Cancel", action: "invokeHireNull" }
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
		for (currentPlayer in players) {
			if (!currentPlayer.isDead && currentPlayer.homeZone.owner != currentPlayer.player) {
				currentPlayer.isDead = true;
			}
		}
		// we'll keep track of defeated factions so we don't let players hire them
		for (neutralFaction in neutrals) {
			if (!neutralFaction.isDead && neutralFaction.homeZone.getUnit(neutralFaction.unit) == null) {
				neutralFaction.isDead = true;
			}
		}

		// we have some special logic for just the Jotnar; if any player is about to befriend
		// them, we should set them back just a bit, since (unlike the Kobolds and Myrkalfar)
		// the Jotnar cease to be neutral once someone befriends them fully
		var jotnarFaction = null;
		for (neutralFaction in neutrals) {
			if (neutralFaction.name == "Jotnar") {
				jotnarFaction = neutralFaction;
				break;
			}
		}
		for (currentPlayer in players) {
			if (!jotnarFaction.isDead) {
				var jotnarRelation = currentPlayer.player.getAlignment(jotnarFaction.faction, false);
				var jotnarCommon = currentPlayer.player.getFactionRelation(jotnarFaction.faction).common;
				if (jotnarRelation > jotnarRelationCap) {
					jotnarCommon.trade -= (jotnarRelation - jotnarRelationCap);
				}
			}
		}

		// we'll limit our objective updates to every 2 seconds instead of every 0.5 seconds to ease up on the computing
		if (state.time % 2 < 0.1) {
			for (currentPlayer in players) {
				if (!currentPlayer.player.isAI && !currentPlayer.isDead) {
					// determine whether we should show this player the overview set of objectives
					// and while we're here, update the relationship progress bars
					var showOverview = currentPlayer.hiring == null;
					currentPlayer.player.objectives.setVisible("victoryExplanation", showOverview);
					for (neutralFaction in neutrals) {
						if (!neutralFaction.isDead) {
							currentPlayer.player.objectives.setCurrentVal("progress" + neutralFaction.name, currentPlayer.player.getAlignment(neutralFaction.faction, false) * relationMultiplier);
						}
						currentPlayer.player.objectives.setVisible("progress" + neutralFaction.name, showOverview && !neutralFaction.isDead);
					}

					// determine whether we should show this player the hiring set of objectives
					var showHire = currentPlayer.hiring == null;
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
						currentPlayer.player.objectives.setVisible("hire" + neutralFaction.name, showHire && thisWilling);
						// if the player can't afford to hire this faction, we'll still show the option but gray it out
						var hireStatus = currentPlayer.player.getResource(neutralFaction.resource) >= neutralFaction.price ? OStatus.Empty : OStatus.Missed;
						currentPlayer.player.objectives.setStatus("hire" + neutralFaction.name, hireStatus);
					}
					// we only want to show the explanation if any of the factions are willing to be hired
					currentPlayer.player.objectives.setVisible("hireExplanation", showHire && anyWilling);

					// determine whether we should show this player the targeting set of objectives
					var showTarget = currentPlayer.hiring != null;
					for (otherPlayer in players) {
						currentPlayer.player.objectives.setVisible("selectTarget", showTarget);
						if (otherPlayer.player != currentPlayer.player && !otherPlayer.isDead) {
							currentPlayer.player.objectives.setVisible("target" + otherPlayer.uid, showTarget);
						}
						currentPlayer.player.objectives.setVisible("cancelTarget", showTarget);
					}
				}
			}
		}
	}
}


function invokeHireJotnar () { var args : Array<Dynamic> = []; args.push(me()); args.push("Jotnar"); invokeHost("setHiring", args); }
function invokeHireKobolds () { var args : Array<Dynamic> = []; args.push(me()); args.push("Kobolds"); invokeHost("setHiring", args); }
function invokeHireMyrkalfar () { var args : Array<Dynamic> = []; args.push(me()); args.push("Myrkalfar"); invokeHost("setHiring", args); }
function invokeHireNull () { var args : Array<Dynamic> = []; args.push(me()); args.push(null); invokeHost("setHiring", args); }
function invokeAttackPlayer0 () { var args : Array<Dynamic> = []; args.push(me()); args.push(0); invokeHost("hireAttack", args); }
function invokeAttackPlayer1 () { var args : Array<Dynamic> = []; args.push(me()); args.push(1); invokeHost("hireAttack", args); }
function invokeAttackPlayer2 () { var args : Array<Dynamic> = []; args.push(me()); args.push(2); invokeHost("hireAttack", args); }
function invokeAttackPlayer3 () { var args : Array<Dynamic> = []; args.push(me()); args.push(3); invokeHost("hireAttack", args); }
function invokeAttackPlayer4 () { var args : Array<Dynamic> = []; args.push(me()); args.push(4); invokeHost("hireAttack", args); }
function invokeAttackPlayer5 () { var args : Array<Dynamic> = []; args.push(me()); args.push(5); invokeHost("hireAttack", args); }
function invokeAttackPlayer6 () { var args : Array<Dynamic> = []; args.push(me()); args.push(6); invokeHost("hireAttack", args); }
function invokeAttackPlayer7 () { var args : Array<Dynamic> = []; args.push(me()); args.push(7); invokeHost("hireAttack", args); }


function setHiring (playerRef : Player, faction : String) {
	var hiredFaction = null;
	for (neutralFaction in neutrals) {
		if (neutralFaction.name == faction) {
			hiredFaction = neutralFaction;
		}
	}
	for (currentPlayer in players) {
		if (currentPlayer.player == playerRef) {
			currentPlayer.hiring = hiredFaction == null ? null : hiredFaction.faction;
		}
	}
}


function hireAttack (playerRef : Player, targetUid : Int) {
	var hiredFaction = null;
	var hiredCount = null;
	for (currentPlayer in players) {
		if (currentPlayer.player == playerRef) {
			for (neutralFaction in neutrals) {
				if (neutralFaction.faction == currentPlayer.hiring) {
					hiredFaction = neutralFaction;
				}
			}
			if (hiredFaction != null) {
				currentPlayer.player.addResource(hiredFaction.resource, -hiredFaction.price);
				var factionRelation = currentPlayer.player.getAlignment(hiredFaction.faction, false);
				var bonusGroups = toInt((factionRelation - relationToHire) / relationPerIncrease);
				hiredCount = hiredFaction.count * (1 + bonusGroups);
				// TODO: apply per-player cooldown so they can't spam hire?
			}
			currentPlayer.hiring = null;
			break;
		}
	}
	for (otherPlayer in players) {
		if (otherPlayer.uid == targetUid) {
			// TODO: send attack
			debug("sending " + hiredCount + " " + hiredFaction.name + " to attack " + otherPlayer.player.name);
			break;
		}
	}
}
