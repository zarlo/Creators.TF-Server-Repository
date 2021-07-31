## Creators.TF Sourcepawn Style Guide, written by sappho.io

Take a look at the [API](https://sourcemod.dev) if you ever need a reference for inbuilt funcs, and don't be afraid to ask any questions you might have. Source sucks ass, and SourcePawn isn't the most sane language either.
That being said, here's some simple rules we can all follow to avoid bugs and confusion

- Please use editorconfig so we can avoid fighting over whitespace, get it for your editor [here](https://editorconfig.org/). If your editor somehow doesn't support it, here is our whitespace style:
    - UTF-8 charset (duh)
    - Unix newlines
    - Trailing newline for text files
    - Spaces of size 4
    - No [trailing whitespace](https://pawelkadluczka-msft.gallerycdn.vsassets.io/extensions/pawelkadluczka-msft/trailingspaceflagger/1.1/1486956303092/147902/1/trailing-spaces-vs.png) (except for our single newline)
- Please do not code golf or microoptimize - readability is key, especially in a less-than-intuitive and outdated language like SourcePawn. A couple extra lines or braces isn't going to hurt anyone.

For example: instead of
```
if (IsValidEntity(ent)) // something;
```
do this:
```
if (IsValidEntity(ent))
{
    // something;
}
```
It avoids hard to find bugs like [this one](https://softwareengineering.stackexchange.com/a/320262), or one that I personally had to track down during our Christmas event involving entity checks and non-braced functions not executing as expected.
This also applies to using `strcmp` or `strncmp` - unless it is a function that is running in something like a SetTransmit hook (which there should not be almost anywhere), just use StrCompare or StrEqual.
- Brace style doesn't really matter, so long as it's not all squashed on a line or two like the above. I am a zoomer so I use a lot of whitespace in general and the [Allman style](https://en.wikipedia.org/wiki/Indentation_style#Allman_style) for my braces, but I am not going to enforce that on others.
- Don't use magic numbers! If you need to set something and use a magic number, at the __very__ least define it or comment it, but most likely it is an enum somewhere in the SDK ([here](https://github.com/ValveSoftware/source-sdk-2013/blob/0d8dceea4310fde5706b3ce1c70609d72a38efdf/mp/src/public/const.h))that you can copy to your pawn plugin or put in an include.
- Don't write something without commenting it unless it's STUPIDLY obvious what it does to someone who doesn't read the language. Again, we're not code golfing, you can spare a couple seconds to write clean code and to write what it does. Try to do `//` comments above code if you can, or multi line ones above chunks of code with `/*  */`.
- __Use `#pragma semicolon 1;` and `#pragma newdecls required`.__ Our CI/CD build process will not compile plugins without proper semicolons at the end of lines, and it does this on purpose to avoid sloppy style. It can't detect newdecls yet, but using outdated and soon to be deprecated syntax is... not good. Please don't do it.
- Don't push plugins that throw warnings on compile. As our lovely Invader has said: "Warnings, they are Errors in disguise." If your plugin is throwing warnings, it is almost certainly something that is a bug and needs to be fixed. In the future, our CI/CD compile process will also refuse to compile plugins with warnings, but we're not there yet.

I know most of this sounds obvious, but in the past people have not done it, resulting in other people having to waste time and reverse engineer someone else's messy and unreadable code. Let's all follow these standards so we can all save each other some time!
