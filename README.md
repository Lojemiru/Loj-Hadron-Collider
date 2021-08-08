# Loj Hadron Collider
A robust, pixel-perfect collision engine for GameMaker Studio 2.3.

Like the extension? Consider [supporting me on Patreon](https://www.patreon.com/lojemiru) to help me maintain this project and develop new ones :)

Need support? Want to ask a question about the extension in general, or just to pester the developer? Join the [Lojcord](https://discord.gg/HTedE6QMKY), or open an issue.

## Why build a custom collision engine?
GameMaker's default collision functions, while useful, are very barebones and lead to a large amount of boilerplate collision code - especially for pixel-perfect collisions. This usually results in projects having an odd mix of imprecise hit detection using built-in collision events and precise movement checks using `for` loops for solid collisions only. On top of that, additional checks are usually required to get the colliding side, colliding instance, etc. This all adds up to collision systems that are inconsistent, inefficient, inaccurate, and inflexible. Furthermore, GameMaker does not offer any form of collision priority definition; collision event order is handled by the engine itself, usually based on instance creation time. Subpixel movement also requires overhead handling that quickly becomes copypasted across entire projects.

I needed a collision engine that handles all of the above in a reasonably efficient manner, so I wrote the Loj Hadron Collider. Maybe you'll find some use out of it too.

## Methodology
So how *do* you go about creating reasonably fast but precise collisions? My methodology for the LHC is to do a single collision check for the whole area the target instance is moving through, and only run per-pixel collision checks if an instance registered in the collision list was found. This means that we only iterate over each pixel when it's absolutely necessary to get the exact point of impact, saving many cycles when instances are moving through empty space.

Beyond that, it's mostly internal sorting and looping optimizations. `repeat(x)` is used everywhere possible rather than other loops for maximum performance. As a result, the LHC is YYC-optimized.

## Documentation

To be written!

## Special thanks
Martin Piecyk, for writing arguably the most famous GameMaker platforming engine that taught me the basics of pixel-perfect collision.

That one l33t Russian hax0r (you know who you are), for giving technical knowledge on looping optimization per-compiler target.
