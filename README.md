# ktistec

Ktistec is an ActivityPub (https://www.w3.org/TR/activitypub/) server.
It is intended for individual users, not farms of users, although
support for additional accounts will be added in the future. It is
designed to have few dependencies -- for example, it uses SQLite as
its database, instead of PostgreSQL + Redis + etc. At the moment, it
supports posting (text and images), followers/following, and threaded
replies, but not much else. It's fast -- a small, threaded
conversation with nesting takes about 9ms to render.

Ktistec powers [Epiktistes](https://epiktistes.com/), my low-volume
home in the Fediverse.

## Installation

At this point, leading up to its first release, you must build the
server from source code. You will need a recent release of the
[Crystal programming language](https://crystal-lang.org/).

## Usage

Since the project is in development, I still build and run the server
on every invocation:

`$ LOG_LEVEL=DEBUG crystal run src/ktistec/server.cr`

The server runs on port 3000. If you're planning on running this in
production, you should put Nginx or Apache in front of it. Don't
forget your SSL certificate!

## Contributors

- [Todd Sundsted](https://github.com/toddsundsted) - creator and maintainer

## Copyright and License

ActivityPub (https://www.w3.org/TR/activitypub/) Server
Copyright (C) 2020 Todd Sundsted

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public
License along with this program. If not, see
(https://www.gnu.org/licenses/).
