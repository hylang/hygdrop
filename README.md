hygdrop
=======

IRC bot for Hy. Has following capabiltiy for now
 1. Can get issue details from github
 2. Can get commit details from github
 3. Prints core members of hylang
 4. evaluates hycode


Usage
-----

Listing Core Team

> list core team members

Bot only finds *members* and *core team* word in the message.

Github issue details

>   hy-mode#14
>   paultag/snitch#2
   
The input should be in form `project/repo#issue_number`, in this case
bot doesn't check if line begins with ,. Similary Github commit can be
accessed

>   hy@3e8941c
>   hylang/hy@3e8941c

In both cases `project` and `repo` is not mandatory, if not given then
bot gets details for `hylang/hy` repository.

TODO
====
- [x] Code can not handle referencing function defined in the same line
- [x] Write a new driver and remove `hygdrop/__init__.hy`
- [x] Integrate spy mode to dump python code
- [] Define DSL to add misc functionalities to bot
 
