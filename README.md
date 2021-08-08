<div align="center"><h1>celun</h1></div>
<div align="center">The <em>customizable embedded Linux using Nix</em>.</div>

* * *

*What even is `celun`?*

It's a *small* Nix-based "extremely embedded" Linux toy distribution.

At the moment the goal is not to replace Nixpkgs, not even for embedded use
cases.

The main goal here is to play around with designs that wouldn't be accepted in
Nixpkgs as they are. In addition, this also serves as a showcase of how a
non-NixOS distribution can be made while still relying on Nixpkgs.

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
