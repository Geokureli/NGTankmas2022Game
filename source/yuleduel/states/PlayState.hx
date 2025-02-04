package yuleduel.states;

import yuleduel.globals.Sounds;
import flixel.util.FlxSort;
import yuleduel.ui.GameCamera;
import flixel.util.FlxColor;
import flixel.FlxCamera;
import flixel.util.FlxTimer;
import flixel.FlxCamera.FlxCameraFollowStyle;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.tile.FlxBaseTilemap.FlxTilemapAutoTiling;
import flixel.tile.FlxTilemap;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxDirectionFlags;
import yuleduel.game.GameMap;
import yuleduel.game.GameObject;
import yuleduel.globals.Dialog;
import yuleduel.globals.GameGlobals;
import yuleduel.ui.DialogFrame;

using StringTools;

class PlayState extends FlxState
{
	public var mapLayer:FlxTypedGroup<FlxTilemap>;
	public var objectLayer:FlxTypedGroup<GameObject>;

	// public var playerLayer:FlxTypedGroup<GameObject>;
	public var baseMap:FlxTilemap = null;
	public var decorativeMap:FlxTilemap = null;

	public var player:GameObject;

	public var ready:Bool = false;

	public var talking:Bool = false;

	public var dialog:DialogFrame;

	public var battleState:BattleState;

	public var collectionState:CollectionState;

	public var mapData:GameMap;

	public var tutSeen:Bool = false;

	public var shopState:ShopState;

	public var gameCamera:GameCamera;

	public var newGame:Bool = true;

	public var roomName:String = "";

	override public function new()
	{
		super();

		destroySubStates = false;

		// gameCamera.bgColor = FlxColor.TRANSPARENT;

		add(mapLayer = new FlxTypedGroup<FlxTilemap>());
		add(objectLayer = new FlxTypedGroup<GameObject>());
		// add(playerLayer = new FlxTypedGroup<GameObject>());
		add(dialog = new DialogFrame());

		// dialog.cameras = [FlxG.camera];

		objectLayer.add(player = new GameObject());

		battleState = new BattleState(returnFromBattle);
		collectionState = new CollectionState(returnFromCollection);
		shopState = new ShopState(returnFromShop);

		setMap("Central_Hub");
	}

	override public function destroy():Void
	{
		// trace("PlayState destroy");
	}

	override function create()
	{
		GameGlobals.transition.transitioning = true;
		var c:FlxCamera = Global.camera;
		FlxG.cameras.remove(Global.camera, false);
		gameCamera = FlxG.cameras.add(new GameCamera(0, 0, Std.int(Global.width / 2), Std.int(Global.height / 2), 2), false);
		mapLayer.cameras = [gameCamera];
		objectLayer.cameras = [gameCamera];
		// playerLayer.cameras = [gameCamera];

		FlxG.cameras.add(c, true);
		c.bgColor = FlxColor.TRANSPARENT;
		GameGlobals.transition.cameras = [c];

		

		super.create();

		fadeIn();
	}

	public function fadeIn():Void
	{
		FlxG.worldBounds.set(0, 2, baseMap.width, baseMap.height - 2);
		gameCamera.setScrollBounds(0, baseMap.width, 2, (baseMap.height - 2));
		gameCamera.follow(player);
		gameCamera.snapToTarget();

		switchMusic();

		GameGlobals.transIn(() ->
		{
			ready = true;
		});
	}

	public function switchMusic():Void
	{
		Sounds.playMusic(getMusicTrack(roomName));
	}

	public function getMusicTrack(RoomName:String):String
	{
		if (RoomName.startsWith("Workshop"))
		{
			return "work_map";
		}
		else if (RoomName.startsWith("Town") || RoomName.startsWith("Central_Hub"))
		{
			return "town_map";
		}
		else if (RoomName.startsWith("Wild"))
		{
			return "wild_map";
		}
		else if (RoomName.startsWith("Castle"))
		{
			return "castle_map";
		}

		return "";
	}

	public function setMap(RoomName:String):Void
	{
		roomName = RoomName;
		mapData = GameGlobals.MapList.get(roomName);

		if (baseMap != null)
		{
			baseMap.kill();
			mapLayer.remove(baseMap, true);
			baseMap = new FlxTilemap();

			decorativeMap.kill();
			mapLayer.remove(decorativeMap, true);
			decorativeMap = new FlxTilemap();

			for (o in objectLayer.members)
			{
				if (o != player)
				{
					o.kill();
					objectLayer.remove(o, true);
				}
			}
			objectLayer.clear();
			objectLayer.add(player);
		}
		else
		{
			baseMap = new FlxTilemap();
			decorativeMap = new FlxTilemap();
		}

		baseMap.loadMapFromArray(mapData.baseLayerData, mapData.widthInTiles, mapData.heightInTiles, Global.asset("assets/images/base_tiles.png"),
			GameGlobals.TILE_SIZE, GameGlobals.TILE_SIZE, FlxTilemapAutoTiling.OFF, 0, 0, 90);
		decorativeMap.loadMapFromArray(mapData.decorativeLayerData, mapData.widthInTiles, mapData.heightInTiles,
			Global.asset("assets/images/decorative_tiles.png"), GameGlobals.TILE_SIZE, GameGlobals.TILE_SIZE, FlxTilemapAutoTiling.OFF, 0, 1, 1);

		decorativeMap.x = decorativeMap.y = baseMap.x = baseMap.y = 0;
		mapLayer.add(baseMap);
		mapLayer.add(decorativeMap);

		// add objects
		var o:GameObject = null;
		var killed:Bool = false;
		for (obj in mapData.objects)
		{
			switch (obj.objectType)
			{
				case PLAYER:
					if (newGame)
					{
						player.spawn("player", "player", obj.x, obj.y, GameObject.facingFromString(obj.facing));
						newGame = false;
					}

				case NPC:
					killed = Dialog.Flags.exists(obj.name + "-dead");
					if (!killed)
					{
						o = objectLayer.getFirstAvailable();
						if (o == null)
						{
							objectLayer.add(o = new GameObject());
						}

						o.spawn(obj.name, obj.sprite, obj.x, obj.y, GameObject.facingFromString(obj.facing));

						if (obj.name == "krampus")
							o.kill();
					}
				default:
			}
		}
	}

	public function spawnObject(Who:String):Void
	{
		Global.camera.flash(0xffffffff, 0.2, () ->
		{
			Global.camera.flash(0xffffffff, 0.2, () ->
			{
				for (o in objectLayer.members)
				{
					if (o.name == Who)
					{
						o.revive();
						return;
					}
				}
			}, true);
		}, true);
	}

	public function giveBadge(Badge:String):Void
	{
		var badgeState:GiveBadgeState = new GiveBadgeState(Badge);
		badgeState.closeCallback = () ->
		{
			ready = true;
			badgeState.destroy();
		};
		openSubState(badgeState);
	}

	public function giveCard(Card:Int):Void
	{
		var cardState:GiveCardState = new GiveCardState(Card);
		cardState.closeCallback = () ->
		{
			ready = true;
			cardState.destroy();
		};
		openSubState(cardState);
	}

	public function killObject(ObjectName:String):Void
	{
		for (o in objectLayer.members)
		{
			if (o.name == ObjectName)
			{
				FlxTween.tween(o, {alpha: 0}, 0.5, {
					onComplete: (_) ->
					{
						o.kill();
						objectLayer.remove(o, true);
					}
				});
			}
		}
	}

	public function showDialog(Dialog:DialogData):Void
	{
		talking = true;
		dialog.display(Dialog);
		ready = true;
	}

	public function showMessage(Message:String):Void
	{
		talking = true;
		dialog.displayMessage(Message);
		ready = true;
	}

	public function checkForObjects(X:Float, Y:Float):GameObject
	{
		for (o in objectLayer.members)
		{
			if (o.alive && o.exists && Std.int(o.x / GameGlobals.TILE_SIZE) == X && Std.int(o.y / GameGlobals.TILE_SIZE) == Y)
				return o;
		}
		return null;
	}

	public function openCollection():Void
	{
		if (!Dialog.checkFlag("seenIntro"))
			return;

		ready = false;

		GameGlobals.transOut(() ->
		{
			// collectionState.refresh();
			openSubState(collectionState);
		});
	}

	public function returnFromTutorial():Void
	{
		ready = true;
		tutSeen = true;
		Dialog.Flags.set("tutSeen", true);
		GameGlobals.save();
	}

	override public function update(elapsed:Float)
	{
		super.update(elapsed);

		if (ready && !tutSeen)
		{
			tutSeen = true;
			ready = false;

			openSubState(new PlayStateTutorial(returnFromTutorial));

			return;
		}

		if (!ready || player.moving)
			return;

		var pause:Bool = Controls.justPressed.PAUSE;
		if (pause && !talking)
		{
			openCollection();
			return;
		}

		var a:Bool = Controls.justPressed.A;

		if (a)
		{
			// if talking, advance/close text
			if (talking)
			{
				talking = false;
				dialog.hide();
				return;
			}
			else
			{
				var dX:Int = player.facing == FlxDirectionFlags.LEFT ? -1 : player.facing == FlxDirectionFlags.RIGHT ? 1 : 0;
				var dY:Int = player.facing == FlxDirectionFlags.UP ? -1 : player.facing == FlxDirectionFlags.DOWN ? 1 : 0;

				var talkTo:GameObject = checkForObjects(Std.int(player.x / GameGlobals.TILE_SIZE) + dX, Std.int(player.y / GameGlobals.TILE_SIZE) + dY);
				if (talkTo != null)
				{
					if (Dialog.talk(talkTo.name))
					{
						return;
					}
				}
			}
			return;
		}

		if (talking && (Controls.justPressed.LEFT || Controls.justPressed.RIGHT))
		{
			if (dialog.isQuestion)
				dialog.changeSelection();
			return;
		}

		if (talking)
			return;

		var left:Bool = Controls.pressed.LEFT;
		var right:Bool = Controls.pressed.RIGHT;
		var up:Bool = Controls.pressed.UP;
		var down:Bool = Controls.pressed.DOWN;
		if (left && right)
			left = right = false;
		if (up && down)
			up = down = false;

		if (up)
			player.move(0, -1, checkPlayerMove);
		else if (down)
			player.move(0, 1, checkPlayerMove);
		else if (left)
			player.move(-1, 0, checkPlayerMove);
		else if (right)
			player.move(1, 0, checkPlayerMove);

		objectLayer.sort((Order, Obj1, Obj2) ->
		{
			return FlxSort.byValues(Order, Obj1.y + Obj1.height, Obj2.y + Obj2.height);
		});
	}

	public function checkPlayerMove():Void
	{
		if (player.x + player.height >= baseMap.y + baseMap.width - 1)
		{
			// moved to the right room
			switchToRoom(RIGHT);
		}
		else if (player.x <= baseMap.x + 1)
		{
			// moved to the left room
			switchToRoom(LEFT);
		}
		else if (player.y + player.height >= baseMap.y + baseMap.height - 1)
		{
			// moved to the bottom room
			switchToRoom(DOWN);
		}
		else if (player.y <= baseMap.y + 1)
		{
			// moved to the top room
			switchToRoom(UP);
		}
	}

	public function openShop():Void
	{
		ready = false;
		GameGlobals.transOut(() ->
		{
			openSubState(shopState);
		});
	}

	public function returnFromShop():Void
	{
		GameGlobals.transIn(() ->
		{
			ready = true;
		});
	}

	public function switchToRoom(Dir:FlxDirectionFlags):Void
	{
		ready = false;

		GameGlobals.transOut(() ->
		{
			var oldX:Float = player.x;
			var oldY:Float = player.y;

			setMap(mapData.neighbors.get(Dir));
			switch (Dir)
			{
				case UP:
					player.x = oldX;
					player.y = baseMap.y + baseMap.height - (GameGlobals.TILE_SIZE * 2);

				case DOWN:
					player.x = oldX;
					player.y = baseMap.y + GameGlobals.TILE_SIZE;

				case LEFT:
					player.x = baseMap.x + baseMap.width - (GameGlobals.TILE_SIZE * 2);
					player.y = oldY;

				case RIGHT:
					player.x = baseMap.x + GameGlobals.TILE_SIZE;
					player.y = oldY;

				default:
			}
			fadeIn();
		});
	}

	public function returnFromBattle(Actions:String):Void
	{
		switchMusic();
		GameGlobals.transIn(() ->
		{
			Dialog.parseScripts([Actions]);
			GameGlobals.save();
		});
	}

	public function returnFromCollection():Void
	{
		GameGlobals.transIn(() ->
		{
			ready = true;
		});
	}

	public function startBattle(Vs:String):Void
	{
		ready = false;
		battleState.init(GameGlobals.Player.deck, Vs);
		GameGlobals.transOut(() ->
		{
			openSubState(battleState);
		});
	}

	override function draw()
	{
		super.draw();
		if (GameGlobals.transition.transitioning)
			GameGlobals.transition.draw();
	}

	public function gameOver():Void
	{
		ready = false;
		var gO:WinScreenState = new WinScreenState();
		gO.closeCallback = () ->
		{
			ready = true;
		};
		openSubState(gO);
	}
}
