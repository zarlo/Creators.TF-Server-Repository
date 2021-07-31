Sourcemod plugins which are developed by us are auto recompiled on each server instance.
So there is no need to store their smxes on repo.

However, if we want to keep some smxes that aren't managed by us and we don't expect them
to be updated so often -- we should keep them in the /external folder. That folder is not
ignored and git tracks all changes, that were made in that folder.

TL;DR - We put anything we don't want to be compiled during update sequence in /external folder.
