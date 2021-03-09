var lanes = [
	[286, 261, 249, 226, 214, 190, 173, 160, 141, 123, 101, 85],
	[280, 262, 243, 232, 215, 195, 178, 158, 137, 124, 102, 82],
	[282, 266, 246, 225, 210, 196, 179, 157, 139, 119, 107, 89],
	[283, 264, 248, 229, 207, 192, 174, 155, 136, 120, 104, 84],
	[285, 265, 247, 230, 209, 197, 171, 161, 138, 121, 99, 88],
	[279, 269, 251, 228, 211, 193, 177, 154, 142, 122, 100, 83],
	[284, 268, 244, 233, 213, 189, 175, 153, 140, 117, 106, 87],
	[287, 263, 245, 227, 212, 191, 176, 159, 135, 118, 103, 815]
];
var foes = [
	[{z: null, u: Unit.Wolf, nb: 4}],
	[{z: null, u: Unit.Death, nb: 4}],
	[{z: null, u: Unit.Bear, nb: 4}],
	[{z: null, u: Unit.Valkyrie, nb: 4}],
	[{z: null, u: Unit.ColossalBoar, nb: 4}, {z: null, u: Unit.Bear, nb: 4}],
	[{z: null, u: Unit.UndeadGiant, nb: 4}, {z: null, u: Unit.Valkyrie, nb: 4}],
	[{z: null, u: Unit.Wyvern, nb: 1}]
];
var foeOffset = lanes[0].length - foes.length;
var furthestColonized = [for (i in 0 ... lanes.length) foeOffset - 2];


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
	// remove all existing victory conditions and set our custom objectives
	state.removeVictory(VictoryKind.VMilitary);
	state.removeVictory(VictoryKind.VFame);
	state.removeVictory(VictoryKind.VMoney);
	state.removeVictory(VictoryKind.VLore);
	state.removeVictory(VictoryKind.VHelheim);
	state.removeVictory(VictoryKind.VOdinSword);
	state.removeVictory(VictoryKind.VYggdrasil);
	if (isHost()) {
		@sync for (currentPlayer in state.players) {
			currentPlayer.objectives.add("racevictory", "Your goal here is very simple: be the first to colonize your entire lane!");
			currentPlayer.objectives.add("matchingvision", "If you want to see how well your competitors are doing, you'll need to make progress yourself! Past the starting area, you'll automatically be able to see as much of the other lanes as you've colonized in yours, plus a little bit beyond.");
			currentPlayer.objectives.add("foerespawn", "To add a little excitement, players can slow down those ahead of them; the first time you colonize each zone, the foes in that corresponding zone on each of the other islands will respawn (though only at half strength)!");
		}
		@sync for (lane in lanes) {
			var laneOwner = getZone(lane[0]).owner;
			for (zoneIndex in 0 ... lane.length) {
				var zone = getZone(lane[zoneIndex]);
				if (zoneIndex < foeOffset) {
					// if we're in the base area, we'll give the players more building room and reveal the zones to everyone
					zone.maxBuildings = 5;
					@sync for (currentPlayer in state.players) {
						currentPlayer.discoverZone(zone);
					}
				}
				else {
					// if we're in the foe zones, we won't let the players build anything, we'll spawn the desired foes,
					// and we'll only reveal the zones to the player who owns the lane (to lessen the lag from seeing such a big map)
					zone.maxBuildings = 0;
					laneOwner.discoverZone(zone);
					var zoneFoes = foes[zoneIndex - foeOffset];
					for (foe in zoneFoes) {
						foe.z = lane[zoneIndex];
					}
					addFoes(zoneFoes);
				}
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
		@sync for (laneIndex in 0 ... lanes.length) {
			var lane = lanes[laneIndex];
			// the first person to colonize their entire lane wins,
			// so let's check if anyone has reached the end of their lane
			var laneOwner = getZone(lane[lane.length - 1]).owner;
			if (laneOwner != null) {
				// we need to make sure nothing was decolonized behind them before granting them the victory
				var victory = true;
				for (zoneId in lane) {
					if (getZone(zoneId).owner != laneOwner) {
						victory = false;
						break;
					}
				}
				if (victory) {
					laneOwner.customVictory("Congratulations, you've won the race!", "Someone else has won the race!");
				}
			}

			// every few updates, let's check to see if we can reveal further
			// we'll show the players each others' lanes based on the furthest they've colonized their own
			// and we'll show them one tile beyond, so they can see if someone is actually ahead of them or just tied
			// we'll also use this colonization check to refresh the matching foe zones in the other lanes, but only up to half strength
			if (toInt(state.time) % 10 == 0) {
				laneOwner = getZone(lane[0]).owner;
				var zoneIndex = lane.length - 1;
				while (zoneIndex > furthestColonized[laneIndex]) {
					if (getZone(lane[zoneIndex]).owner == laneOwner) {
						furthestColonized[laneIndex] = zoneIndex;
						@sync for (otherLane in lanes) {
							if (otherLane[0] != lanes[laneIndex][0]) {
								if (zoneIndex < (lane.length - 1)) {
									laneOwner.discoverZone(getZone(otherLane[zoneIndex + 1]));
								}
								if (zoneIndex >= foeOffset) {
									var zoneFoes = [];
									for (foe in foes[zoneIndex - foeOffset]) {
										zoneFoes.push({
											z: otherLane[zoneIndex],
											u: foe.u,
											nb: max(1, toInt(foe.nb / 2))
										});
									}
									killFoes(zoneFoes);
									addFoes(zoneFoes);
								}
							}
						}
						break;
					}
					--zoneIndex;
				}
			}
		}
	}
}
