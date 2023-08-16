# Librewolf Gentoo

Librewolf packaging for Gentoo.

## Usage

### Manual way

Create the `/etc/portage/repos.conf/justxls-librewolf.conf` file as follows:

```
[justxls-librewolf]
priority = 50
location = <repo-location>/justxls-librewolf
sync-type = git
sync-uri = https://github.com/JustXLS/justxls-librewolf.git
auto-sync = Yes
```

Change `repo-location` to a path of your choosing and then run `emerge --sync librewolf`, Portage should now find and update the repository.

### Eselect way

On terminal:

```bash
sudo eselect repository add justxls-librewolf git https://github.com/JustXLS/justxls-librewolf.git
```

### Layman way

On terminal:

```bash
sudo layman -o https://github.com/JustXLS/justxls-librewolf/-/raw/master/repository.xml -f -a justxls-librewolf
```

And then run `emerge --sync justxls-librewolf`, Portage should now find and update the repository.

## Contributing

Before submitting an issue please verify that the issue doesn't occur on Gentoo's `www-client/firefox` package.

## Packaging Workflow

To make things easy to update the `www-client/librewolf` and `www-client/librewolf-bin` ebuilds are based on the `www-client/firefox(-bin)` ebuilds from Gentoo's default repository.

_Personally I use `diff -aur <librewolf ebuild> <firefox ebuild>` when making version bumps._
