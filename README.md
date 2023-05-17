# yala
Yala is just Yet Another Log Analyzer.  It focuses on providing quick JBoss EAP 7+ server log summaries, highlighting known critical ERRORs, and counts of other general errors at a glance.

# installation
* To install, run the following in a directory where you want to keep the script and known error file references:
```
wget https://raw.githubusercontent.com/aogburn/yala/main/yala.sh
chmod 755 yala.sh
wget https://raw.githubusercontent.com/aogburn/yala/master/yala-errors.tar.xz
tar -xf yala-errors.tar.xz
```

# updating 

When run, yala will look for a new version to use and update itself with a simple wget if so. This update check can be omitted by using the option '-u, --updateMode' with either the value 'never' (no update check is being performed) or 'ask' (the user is asked to update if a new version is found). The script may be updated over time with new helpful checks, stats, or known issue searches.

# usage

* To run:
```
 ./yala.sh server.log
```
* Options:
```
 -l, --last              analyse the last started JBoss only
 -u, --updateMode        the update mode to use, one of [force ask never], default: force
 -h, --help              show this help
```
