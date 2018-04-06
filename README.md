# loggerbot
loggerbot is a hobby project I started in the mid-2000's sometime. I recently ran across the code, decided to clean it up a bit and publish to github. It used to dump all parsed data from IRC into a sqlite database, but that is SO 2005. I intend on adapting this to dump to elastic and writing a simple frontend to display/search through the log data.

To configure you must modify the header of the source to define your networks and channels.

```
my $nick = "BotNickName"; # No spaces. limits depend on irc server
my $username = "BotUserName"; # ident
my $realname = "Bots Real Name"; # real name (LOL! right)

my $networks = {
  'FreeNode' => { 'server' => 'irc.freenode.org', 'channels' => ['#debian', '#perl', '##C', '##C++', '##linux']},
  'Network2' => { 'server' => 'some-irc-server.com', 'password' => 'IRC SERVER PASSWORD! NOT NICKSERV!', 'channels' => ['#list', '#of', '#channels']}
};
```
