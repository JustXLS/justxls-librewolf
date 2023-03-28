# Librewolf Gentoo

Librewolf packaging for Gentoo.

## Usage

### Manual way

Create the `/etc/portage/repos.conf/librewolf.conf` file as follows:

```
[librewolf]
priority = 50
location = <repo-location>/librewolf
sync-type = git
sync-uri = https://gitlab.com/librewolf-community/browser/gentoo.git
auto-sync = Yes
```

Change `repo-location` to a path of your choosing and then run `emerge --sync librewolf`, Portage should now find and update the repository.

### Eselect way

On terminal:

```bash
sudo eselect repository add librewolf git https://gitlab.com/librewolf-community/browser/gentoo.git
```

### Layman way

On terminal:

```bash
sudo layman -o https://gitlab.com/librewolf-community/browser/gentoo/-/raw/master/repository.xml -f -a librewolf
```

And then run `emerge --sync librewolf`, Portage should now find and update the repository.

## Packaging Workflow (for contributors)

The upstream branch contains a mirror of the [Gentoo mozilla overlay](https://gitweb.gentoo.org/proj/mozilla.git/) we want to re-use as much as possible from Gentoo (the mozilla eclasses) and make as litttle changes as possible. This should make it easier to update in the future. The upstream branch should be periodically updated with any necessary changes merged into master.
