extends RefCounted
## **The channel a build is on, and the pair of ports it takes from it.**
##
## A build that follows a branch's rolling prerelease -- `BuildInfo.release_branch`
## not empty: the dev app, and the dev server beside it -- is on that
## **branch's channel**. Every other build, the one players have, is on the
## **release channel**. The release channel keeps the pair it always had,
## `Lan.PORT` and `Invite.PORT`; a branch channel takes each
## [constant BRANCH_SHIFT] higher. So a branch's app and a branch's server
## find each other and nothing else: not a live server on the same machine,
## not a phone in the house on the release app, and not the live server's
## forward on the router.
##
## **Everything that binds, dials, forwards, prints or defaults a port asks
## here**, through `Lan.channel_port()` and `Invite.channel_port()`. The wire,
## `Wire.PROTOCOL` and the rules are the same on both channels: this moves the
## ports and nothing a port carries.
##
## **The stamp is BuildInfo's**, read the first time a port is asked for and
## fixed for the life of the process. BuildInfo reads it from the binary's own
## build stamp before any content pack mounts, and refuses a pack staged for
## another branch -- so nothing a pack carries can move a build onto another
## channel. With no BuildInfo at all, it is the release channel.
##
## It knows two kinds of channel and nothing else: which branch it is, and what
## anything is called on it, are said at the edges.
##
## No class_name on purpose -- see the note at the top of signal_bus.gd.

## **How much higher a branch channel's ports are**: 45781 and 45782, beside
## the release channel's 45771 and 45772 -- still unregistered, and high.
const BRANCH_SHIFT := 10

## **A tool's seam**: while it is set, this process poses as a build of that
## branch -- "" poses as the release channel -- until it is set back to null.
## Nothing a player or an owner runs sets it, and no flag reaches it.
static var posing: Variant = null

## The branch in BuildInfo's stamp, once read; null until the first ask.
static var _stamp: Variant = null


## **The branch whose channel this build is on**, or "" on the release channel.
static func branch() -> String:
	if posing != null:
		return str(posing)
	if _stamp == null:
		_stamp = _read_stamp()
	return str(_stamp)


## True on a branch's channel: the build follows a branch's rolling prerelease.
static func is_branch() -> bool:
	return not branch().is_empty()


## **[param release], a port as the release channel has it, on this build's
## channel**: the same port on the release channel, [constant BRANCH_SHIFT]
## higher on a branch's. The one place the pair is picked.
static func port(release: int) -> int:
	return release + (BRANCH_SHIFT if is_branch() else 0)


## `BuildInfo.release_branch`, or "" when there is no BuildInfo to ask -- or
## one from before the stamp had a branch, which only a release build can be.
static func _read_stamp() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return ""
	var info := tree.root.get_node_or_null(^"BuildInfo")
	var said: Variant = info.get("release_branch") if info != null else null
	return said if said is String else ""
