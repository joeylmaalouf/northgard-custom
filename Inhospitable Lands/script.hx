var centerZone = getZone(153);
var homeZones = [for (i in [100, 89, 113, 154, 202, 243, 208, 161]) getZone(i)];
var isViewingMissions = [false, false, false, false, false, false, false, false];
var humanPlayers = [];
var endingWarned = false;
var timeLimit = 4 * 12 * 60;
var endWarningTime = 12 * 60;
var eventWarningDelay = 2 * 60;
var eventTimer = 4 * 60;
var eventOffset = 2 * 60;
var landZoneCount = 74;
var allScouted = false;
var defeatedSkrymir = false;
var defeatedFjolsvin = false;
var defeatedKobolds = false;
var defeatedMyrkalfar = false;
var yggdrasil = null;
var cutsceneStarted = false;
var cutsceneOver = false;


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
	// remove all existing victory conditions besides Yggdrasil
	state.removeVictory(VictoryKind.VMilitary);
	state.removeVictory(VictoryKind.VFame);
	state.removeVictory(VictoryKind.VMoney);
	state.removeVictory(VictoryKind.VLore);
	state.removeVictory(VictoryKind.VHelheim);
	state.removeVictory(VictoryKind.VOdinSword);
	if (isHost()) {
		@sync for (currentPlayer in state.players) {
			if (!currentPlayer.isAI) {
				humanPlayers.push(currentPlayer);
				currentPlayer.addBonus({ id: Bonus.BMoreSheeps, isAdvanced: false });
				currentPlayer.objectives.add("inhospitablelands", "These lands are particularly inhospitable, so disasters will strike more frequently than normal (and with less warning)!");
				currentPlayer.objectives.add("recklessscouts", "Your [Scout]s are a little too reckless for this environment, so while they will explore more quickly, they'll also die immediately afterwards.");
				currentPlayer.objectives.add("lazyvillagers", "And your [Villager]s are a little lazy when it comes to gathering food, so your [Sheep] will have to pick up the slack. Thankfully, they'll breed new ones each year.");
				currentPlayer.objectives.add("colonizetree", "To conquer these lands, you must work together to enable one of you to colonize [Yggdrasil] before " + timeLimit / 12 / 60 + " years have passed, or else the World Tree will reclaim these lands!");
				currentPlayer.objectives.add("bonusmissions", "To help each other out, you can gain bonuses for your team by completing side missions:", null, { name: "View missions", action: "invokeViewingMissions" });
				currentPlayer.objectives.add("returntomain", "Return to the main menu:", { visible: false }, { name: "Go back", action: "invokeViewingMainMenu" });
				currentPlayer.objectives.add("scoutbonus", "Scout the entire map to give everyone a free feast!", { visible: false });
				currentPlayer.objectives.add("skrymirbonus", "Defeat the [Giant]s to give everyone the [BetterSilo] Knowledge!", { visible: false });
				currentPlayer.objectives.add("fjolsvinbonus", "Defeat the [Giant2]s to give everyone the [BuildingUpkeep] Knowledge!", { visible: false });
				currentPlayer.objectives.add("koboldsbonus", "Defeat the [Kobold]s to give everyone the [Recruit] Knowledge!", { visible: false });
				currentPlayer.objectives.add("myrkalfarbonus", "Defeat the [Myrkalfar]s to give everyone [Stone] and [Iron]!", { visible: false });
			}
		}

		// we don't want any events to happen naturally, we'll be triggering them ourselves
		noEvent();

		// we want it to be appropriately challenging to clear out Yggdrasil
		centerZone.addUnit(Unit.IceGolem, humanPlayers.length * 2, null, false);

		// we have a few rules to make the environmental difficulty even more intense
		addRule(Rule.Biggdrasil);
		addRule(Rule.LethalScouts);
		addRule(Rule.LethalRuins);
		// I'd like to use MoreReqHappyFoodConsumption, but it doesn't seem to do anything, so instead we'll have the villagers be lazy
		addRule(Rule.VillagerStrike);
		// though we'll compensate a little by giving the town hall a base food income
		addRule(Rule.ExtraFoodProduce);
		// but FoodStarterPack also doesn't seem to work, so we'll add the resources ourselves
		@sync for (currentPlayer in state.players) {
			currentPlayer.addResource(Resource.Food, 200, false);
		}
	}

	// we'll want a reference to Yggdrasil for later use in the cutscene
	for (building in centerZone.buildings) {
		if (building.kind == Building.Yggdrasil) {
			yggdrasil = building;
			break;
		}
	}
}


function onEachLaunch () {
	// we don't support saving and loading yet
}


// Regular update is called every 0.5s
function regularUpdate (dt : Float) {
	if (isHost()) {
		// if Yggdrasil is finished colonizing, trigger victory
		if (centerZone.owner != null) {
			centerZone.owner.customVictory("You've tamed these lands!", "If you can see this message, something is wrong with the team setup!");
		}

		// if time's up and we haven't finished colonizing Yggdrasil, trigger defeat
		if (state.time > timeLimit) {
			// before we actually end it, we'll show a cutscene where Yggdrasil takes the island back
			if (!cutsceneStarted) {
				invokeAll("defeatCutscene", []);
			}
			if (cutsceneOver) {
				@sync for (currentPlayer in state.startPlayers) {
					currentPlayer.customDefeat("You've failed to take over these lands in time!");
				}
			}
		}

		if (!endingWarned) {
			// if we're getting close to the time limit, let the players know
			if (state.time >= (timeLimit - endWarningTime + 1)) { // we have to wait a second so the last event before this will actually trigger
				state.events.setEvent(Event.GameEnd, endWarningTime / 60);
				endingWarned = true;
			}
			// until we get close to the end, we'll trigger an event every few months to make things that much harder
			else if ((state.time + eventOffset + eventTimer - eventWarningDelay) % eventTimer < 0.1) {
				var eventMonth = ((state.time + eventTimer - eventWarningDelay) % 720) / 60; // 0-11, Mar-Feb
				var eventKind = eventMonth >= 9 ? Event.Blizzard : [Event.Rats, Event.Earthquake][randomInt(2)];
				state.events.setEvent(eventKind, (eventTimer - eventWarningDelay) / 60);
			}
		}

		// every few seconds, we'll update the objectives menu and check the side missions to see whether we can grant the players any additional bonuses
		if (state.time % 2 < 0.1) {
			@sync for (playerIndex in 0 ... homeZones.length) {
				var currentPlayer = homeZones[playerIndex].owner;
				if (!currentPlayer.isAI) {
					var viewingMissions = isViewingMissions[playerIndex];
					currentPlayer.objectives.setVisible("inhospitablelands", !viewingMissions);
					currentPlayer.objectives.setVisible("recklessscouts", !viewingMissions);
					currentPlayer.objectives.setVisible("lazyvillagers", !viewingMissions);
					currentPlayer.objectives.setVisible("colonizetree", !viewingMissions);
					currentPlayer.objectives.setVisible("bonusmissions", !viewingMissions);
					currentPlayer.objectives.setVisible("returntomain", viewingMissions);
					currentPlayer.objectives.setVisible("scoutbonus", viewingMissions);
					currentPlayer.objectives.setVisible("skrymirbonus", viewingMissions);
					currentPlayer.objectives.setVisible("fjolsvinbonus", viewingMissions);
					currentPlayer.objectives.setVisible("koboldsbonus", viewingMissions);
					currentPlayer.objectives.setVisible("myrkalfarbonus", viewingMissions);
				}
			}

			// we can just check one player's discovered zones here because they're all a team and therefore share them,
			// but we can't compare against state.zones because it includes sea zones so we're using a precalculated landZoneCount
			if (!allScouted && me().discovered.length >= landZoneCount) {
				@sync for (currentPlayer in state.players) {
					++currentPlayer.freeFeast;
					if (!currentPlayer.isAI) { currentPlayer.objectives.setStatus("scoutbonus", OStatus.Done); }
				}
				allScouted = true;
			}
			if (!defeatedSkrymir && getFaction("Giant") == null) {
				@sync for (currentPlayer in state.players) {
					currentPlayer.unlockTech(Tech.BetterSilo, true);
					if (!currentPlayer.isAI) { currentPlayer.objectives.setStatus("skrymirbonus", OStatus.Done); }
				}
				defeatedSkrymir = true;
			}
			if (!defeatedFjolsvin && getFaction("Giant2") == null) {
				@sync for (currentPlayer in state.players) {
					currentPlayer.unlockTech(Tech.BuildingUpkeep, true);
					if (!currentPlayer.isAI) { currentPlayer.objectives.setStatus("fjolsvinbonus", OStatus.Done); }
				}
				defeatedFjolsvin = true;
			}
			if (!defeatedKobolds && getFaction("Kobold") == null) {
				@sync for (currentPlayer in state.players) {
					currentPlayer.unlockTech(Tech.Recruit, true);
					if (!currentPlayer.isAI) { currentPlayer.objectives.setStatus("koboldsbonus", OStatus.Done); }
				}
				defeatedKobolds = true;
			}
			if (!defeatedMyrkalfar && getFaction("Myrkalfar") == null) {
				@sync for (currentPlayer in state.players) {
					currentPlayer.addResource(Resource.Stone, 15, false);
					currentPlayer.addResource(Resource.Iron, 10, false);
					if (!currentPlayer.isAI) { currentPlayer.objectives.setStatus("myrkalfarbonus", OStatus.Done); }
				}
				defeatedMyrkalfar = true;
			}
		}
	}
}


function defeatCutscene () {
	cutsceneStarted = true;
	setPause(true);
	moveCamera({x: yggdrasil.x, y: yggdrasil.y});
	wait(1);
	shakeCamera();
	if (isHost()) {
		for (zone in centerZone.next) {
			for (building in zone.buildings) {
				building.destroy();
			}
			// TODO: when the API lets us add buildings and not just destroy them, turn everything into Naströnd/Landvidi
		}
	}
	wait(1);
	setPause(false);
	cutsceneOver = true;
}


function getPlayerIndex (currentPlayer : Player) {
	for (i in 0 ... homeZones.length) {
		if (homeZones[i].owner == currentPlayer) {
			return i;
		}
	}
	return -1;
}


function invokeViewingMissions () { var args : Array<Dynamic> = []; args.push(me()); args.push(true); invokeHost("setViewingMissions", args); }
function invokeViewingMainMenu () { var args : Array<Dynamic> = []; args.push(me()); args.push(false); invokeHost("setViewingMissions", args); }
function setViewingMissions (currentPlayer : Player, value : Bool) { isViewingMissions[getPlayerIndex(currentPlayer)] = value; }
