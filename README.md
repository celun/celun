<div align="center"><h1>celun</h1></div>
<div align="center">The <em>customizable embedded Linux using Nix</em>.</div>

* * *

*What even is celun?*

It's a *small* *Nix*-based "extremely embedded" Linux toy distribution.

At the moment the goal is not to replace *Nixpkgs*, not even for embedded use
cases.

The main goal here is to play around with designs that wouldn't be accepted in
*Nixpkgs* as they are. In addition, this also serves as a showcase of how a
non-*NixOS* distribution can be made while still relying on *Nixpkgs*.

This is entirely a learning exercise, for the author, and anyone else reading
this.

Hopefully some of these experiments can graduate into more "proper" projects
as they become mature :).

* * *

Some design decisions
---------------------

*Devices* are used to describe as much as relevant about a hardware target.
These properties are used by default to maximally customize the built system.

*Hardware* options are described in `modules/hardware`. These are expected to
be used by devices to describe themselves. Some options may be unused.

> **This smells like *Mobile NixOS*, no?** Yes it does! But this factors out
> the hardware into an even more generic overview. I want to stretch the use
> case even further than it is in *Mobile NixOS*.

* * *

FAQ
---

### This replaces *NixOS*, right?

Not in most of the use cases where it shines! And even for those other cases it
might still be desirable to use *NixOS* and all its semantics.

The only segment I envision this project doing better than *NixOS* is for
*extremely embedded Linux*, where most of the *NixOS* semantics won't matter. And
yet, it should be possible to use *NixOS* in most of those cases. Please do if
it works for you!

Note that this *is not using NixOS*. It uses the *modules system*, like *NixOS*
does, but the modules are mostly entirely new and have different semantics.


### So this replaces *Nixpkgs*?

No! This uses and leverages *Nixpkgs*! *Nixpkgs* has years upon years of
accumulated knowledge about building software for Linux systems. It would be a
shame to entirely throw it away!


### Then, why use this?

For now, not many reasons. You'd be an early adopter and probably need to stamp
down your own path with *celun*.

With that said, if you think *celun* is something you want to use, get in
touch, collaboration does wonders! Your ideas and use cases may influence the
initial design of *celun* greatly!
