# Creators.TF Server Repository
This is the repository that contains all of the code, configs, and content for the Creators.TF Servers. Creators.TF Servers have a lot of custom content such as custom weapons, cosmetics, strange parts, campaigns, just to name a few. A lot of this repository is the economy code (usually starting in `cecon_` or `ce_`), which is responsible for all of the previously mentioned custom features.

To clone this project:

```
git clone --recurse-submodules <git@gitlab.com:creators_tf/gameservers/servers.git>
```
or if you've already cloned the project,

```
git pull
git submodule update --init --recursive
```

The CI/CD scripts will automatically manage deployment out to all game servers when a commit is pushed.

## SourcePawn Development File Structure
File Structure: `<root install> / servers / tf / addons / sourcemod`
- ∟ **scripting** - All raw Sourcepawn files. All files ending in .sp that have been changed will be compiled into .smx files when a commit is pushed. They will then be automatically deployed onto game servers. 
    - ∟ attributes - Sourcepawn files that relate to custom weapon, item, or object attributes. Also includes specific provider economy features (e.g Creators.TF Strange’s).
    - ∟ disabled - Sourcepawn files that are compiled and are immediately moved to /disabled on compile.
    - ∟ discord - Files required for the Seed bot on the Creators.TF Discord.
    - ∟ external - Sourcepawn files that are not made by the team.
    - ∟ fixes - Sourcepawn files that have quality of life changes to TF2’s gameplay.
    - ∟ include - Sourcepawn include files.
    - ∟ sbpp - Sourcepawn files required for SourceBans++.
- ∟ **plugins** - Sourcemod plugins which are developed by us are auto recompiled on each server instance. So there is no need to store their compiled versions on the repo. However, if we want to keep some compiled plugins that aren't managed by us and we don't expect them to be updated so often -- we should keep them in the external folder. That folder is not ignored and git tracks all changes that were made in that folder.
- ∟ **configs** - All of the config files required for our plugins.
    - ∟ cecon_items - See [Injecting Custom Items](https://gitlab.com/creators_tf/servers/-/wikis/Injecting-Custom-Items).
    - ∟ regextriggers - Config files required for the regex triggers plugin. Do not touch unless you know what you’re doing. 
    - ∟ sourcebans - Config files for SourceBans.
    - ∟ economy_$x.cfg - These config files are loaded in by cecon_core.smx  when it’s loaded so backend HTTP requests can go through. Do not touch these unless you have permission from a Core Developer.

## Economy Plugin Outline
- `cecon_core` - Responsible for establishing contact with the website via Long-Polling. Also handles parsing the Economy Schema from the website and sending Creators.TF Events to Clients. This plugins is required for the economy to work.
- `cecon_items` - The core item for custom override items to work. This plugin handles getting player loadouts from the website, equipping items on players and calling forwards to other sub-item plugins.
- `cecon_item_weapon` - Implements logic that creates custom weapons for the player.
- `cecon_item_cosmetic` - Implements logic that creates custom cosmetics for the player.
- `cecon_item_soundtrack` - Implements logic that creates custom music-kits for the player.
- `cecon_contracts` - Handles receiving and updating custom player contracts with data from Creators.TF Events.
- `cecon_tf2_events` - Creates Creators.TF Events based on ingame events.
- `cecon_mvm_events` - Creates Creators.TF Events based on ingame events.
- `cecon_mvm` - Handles the logic for controlling MVM-only gameservers.
- `cecon_patreon` - Handles giving players ingame tags based on their Patreon subscription.
- `cecon_http` - Natives to create HTTP requests to the website.
- `cecon_matchmaking` - Currently unused due to Quickplay not being in active development.
- `cecon_quickswitch` - Implements the !qs command to quickly switch between items in a slot without having to open the website.
- `cecon_nohats` - Implements a command that can disable Creators.TF cosmetics for a player.
- `cecon_giveitem` - Used to give Economy Items to admins without equipping them on the website.
- `cecon_campaigns` - Handles receiving and updating campaigns with data from Creators.TF Events.
- `cecon_stats` - Currently unfinished: Used to send statistics to the website with data from Creators.TF Events.

## Game Server Configuration
There are three types of `.cfg` files to worry about:
- `quickplay/base` - All game servers will execute this first to setup the basic gameplay and necessary convars.
- `quickplay/$x00` - Depending on the region the server is in, this file will get executed to set the IP for the calladmin command.

---

The game server regions are as follows:
- 100 - West Europe
- 200 - East US (Virginia)
- 300 - West US (LA)
- 400 - West US (Chicago)
- 500 - Brazil
- 600 - Australia (Sydney)
- 700 - Singapore
- 800 - Maryland (Potato's Custom MvM Servers)
- 850 - Europe (Potato's Custom MvM Servers)

---

- `quickplay/server-$xxx` - Each individual game server has it's own config file so it can set it's hostname and server index number. This config file will call the other two files previously mentioned.

## Scripts 
STRTA: or Scripts To Rule Them All:
- `.scripts/helpers.sh`: Contains an useful collection of shared functions.
- `.scripts/ci.sh`: Master script for running ci.
- `.scripts/_1-pull.sh`: Updates the repository in it's current directory with master 
- `.scripts/_2-build.sh`: Recursively compiles any uncompiled `.sp` plugin in it's current directory and (if given a git reference) any `.sp` in need of an update.

 
