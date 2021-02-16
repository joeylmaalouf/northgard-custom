var centerZone = getZone(153);
var humanPlayers = [];
var endingWarned = false;
var timeLimit = 60 * 60;
var endWarningTime = 12 * 60;
var eventWarningTime = 1 * 60;
var eventOffset = 2 * 60;
var eventTimer = 4 * 60;


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
				currentPlayer.objectives.add("inhospitablelands", "These lands are particularly inhospitable, so disasters will strike more frequently than normal!");
				currentPlayer.objectives.add("recklessscouts", "Your [Scout]s are a little too reckless for this environment, so while they will explore more quickly, they'll also die immediately afterwards.");
				currentPlayer.objectives.add("lazyvillagers", "And your [Villager]s are a little lazy when it comes to gathering food, so your [Sheep] will have to pick up the slack. Thankfully, they'll breed new ones each year.");
				currentPlayer.objectives.add("colonizetree", "To conquer these lands, you must work together to enable one of you to colonize [Yggdrasil] before time is up!");
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
		// but FoodStarterPack also doesn't seem to work, so we'll add the resources ourselves
		@sync for (currentPlayer in state.players) {
			currentPlayer.addResource(Resource.Food, 200, false);
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
			@sync for (currentPlayer in state.startPlayers) {
				currentPlayer.customDefeat("You've failed to take over these lands in time!");
			}
		}

		if (!endingWarned) {
			// if we're getting close to the time limit, let the players know
			if (state.time > (timeLimit - endWarningTime)) {
				state.events.setEvent(Event.GameEnd, endWarningTime / 60);
				endingWarned = true;
			}
			// until we get close to the end, we'll trigger an event every few months to make things that much harder
			else if ((state.time + eventOffset + eventTimer - eventWarningTime) % eventTimer < 0.1) {
				var eventMonth = ((state.time + eventTimer - eventWarningTime) % 720) / 60; // 0-11, Mar-Feb
				var eventKind = eventMonth >= 9 ? Event.Blizzard : [Event.Rats, Event.Earthquake][randomInt(2)];
				state.events.setEvent(eventKind, (eventTimer - eventWarningTime) / 60);
			}
		}
	}
}
